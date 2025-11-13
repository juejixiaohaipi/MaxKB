#!/bin/bash

# 提取差异文件到纯净分支
# 用法: 
#   ./extract-changes.sh                    # 使用默认设置
#   ./extract-changes.sh main               # 指定目标分支
#   ./extract-changes.sh main new-branch    # 指定目标分支和新分支名

# example
# ./extract-changes.sh feature/release-2.2   

set -euo pipefail

# 颜色输出函数
error() { echo -e "\033[0;31m❌ $1\033[0m" >&2; }
success() { echo -e "\033[0;32m✅ $1\033[0m"; }
warning() { echo -e "\033[1;33m⚠️  $1\033[0m"; }
info() { echo -e "\033[0;34m📝 $1\033[0m"; }

# 保存原始分支
original_branch=$(git branch --show-current)

# 参数处理
target_branch="${1:-main}"
new_branch="${2:-${original_branch}-clean}"

# 显示执行信息
echo "🚀 开始提取差异文件"
info "当前分支: $original_branch"
info "对比分支: $target_branch"
info "新分支名: $new_branch"
echo

# 检查Git仓库状态
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    error "当前目录不是Git仓库"
    exit 1
fi

# 检查目标分支
if ! git show-ref --verify --quiet "refs/heads/$target_branch"; then
    error "目标分支 '$target_branch' 不存在"
    echo "可用分支:"
    git branch --list | sed 's/^/  /'
    exit 1
fi

# 获取差异文件（在切换分支前获取）
info "分析文件差异..."
mapfile -t changed_files < <(git diff "$target_branch" --name-only --diff-filter=ACMR 2>/dev/null || true)

if [ ${#changed_files[@]} -eq 0 ]; then
    error "没有找到差异文件"
    info "当前分支 '$original_branch' 与 '$target_branch' 内容相同"
    exit 1
fi

# 显示差异文件
success "发现 ${#changed_files[@]} 个差异文件:"
printf '  %s\n' "${changed_files[@]:0:10}"
[ ${#changed_files[@]} -gt 10 ] && warning "... 还有 $(( ${#changed_files[@]} - 10 )) 个文件"
echo

# 清理现有分支
if git show-ref --verify --quiet "refs/heads/$new_branch"; then
    warning "删除已存在的分支 '$new_branch'"
    git branch -D "$new_branch" > /dev/null
fi

# 创建纯净分支并彻底清理
info "创建纯净分支..."
git checkout --orphan "$new_branch" > /dev/null

# 彻底清理工作区
info "彻底清理工作区..."
git reset --hard > /dev/null
git clean -fd > /dev/null

# 检查当前状态
if [ -n "$(git status --porcelain)" ]; then
    warning "工作区仍有未清理文件，强制删除..."
    # 强制删除所有文件，除了 .git 目录
    find . -mindepth 1 -maxdepth 1 -not -name '.git' -exec rm -rf {} + 2>/dev/null || true
fi

# 验证工作区是否干净
if [ -n "$(ls -A . 2>/dev/null | grep -v '^.git$')" ]; then
    error "工作区清理失败，仍有文件存在"
    git checkout "$original_branch" > /dev/null 2>&1 || true
    exit 1
fi

# 提取文件
info "提取文件中..."
extracted_files=()
skipped_files=()

for file in "${changed_files[@]}"; do
    # 使用原始分支名称来提取文件
    if git show "$original_branch":"$file" > /dev/null 2>&1; then
        mkdir -p "$(dirname "$file")"
        if git checkout "$original_branch" -- "$file" > /dev/null 2>&1; then
            success "提取: $file"
            extracted_files+=("$file")
        else
            warning "提取失败: $file"
            skipped_files+=("$file")
        fi
    else
        warning "跳过: $file (文件不存在于分支 $original_branch)"
        skipped_files+=("$file")
    fi
done

# 检查提取结果
if [ ${#extracted_files[@]} -eq 0 ]; then
    error "没有成功提取任何文件"
    info "尝试返回原分支..."
    git checkout "$original_branch" > /dev/null 2>&1 || true
    git branch -D "$new_branch" > /dev/null 2>&1 || true
    exit 1
fi

# 提交更改
info "提交更改..."
git add "${extracted_files[@]}"

# 验证提交内容
current_files=$(git ls-files | wc -l)
if [ "$current_files" -ne "${#extracted_files[@]}" ]; then
    warning "文件数量不匹配: 期望 ${#extracted_files[@]} 个，实际 $current_files 个"
    info "当前工作区文件:"
    git ls-files | head -10
    [ "$current_files" -gt 10 ] && warning "... 还有 $((current_files - 10)) 个文件"
fi

if [ -z "$(git status --porcelain)" ]; then
    error "没有文件可提交"
    git checkout "$original_branch" > /dev/null 2>&1 || true
    git branch -D "$new_branch" > /dev/null 2>&1 || true
    exit 1
fi

# 生成提交信息
commit_msg="提取差异文件 | 源分支: $original_branch -> 目标分支: $target_branch

包含 ${#extracted_files[@]} 个文件:"
for file in "${extracted_files[@]:0:20}"; do
    commit_msg="$commit_msg"$'\n'"  - $file"
done
[ ${#extracted_files[@]} -gt 20 ] && commit_msg="$commit_msg"$'\n'"  ... 还有 $(( ${#extracted_files[@]} - 20 )) 个文件"

[ ${#skipped_files[@]} -gt 0 ] && commit_msg="$commit_msg"$'\n'$'\n'"跳过 ${#skipped_files[@]} 个文件（不存在或提取失败）"

git commit --no-verify -m "$commit_msg" > /dev/null

# 显示结果
echo
success "完成！"
echo "📊 统计信息:"
echo "  ✅ 成功提取: ${#extracted_files[@]} 个文件"
echo "  ⚠️  跳过文件: ${#skipped_files[@]} 个文件"
echo "  📍 新分支: $new_branch"
echo "  🔑 提交ID: $(git rev-parse --short HEAD)"
echo "  📁 新分支文件总数: $(git ls-files | wc -l)"

# 验证文件数量
if [ $(git ls-files | wc -l) -eq ${#extracted_files[@]} ]; then
    success "✅ 验证通过: 新分支只包含差异文件"
else
    warning "⚠️  文件数量不匹配，新分支可能包含其他文件"
    info "新分支文件列表:"
    git ls-files | head -15
fi

# 返回原分支
info "返回原分支 $original_branch ..."
git checkout "$original_branch" > /dev/null

# 操作建议
echo
info "下一步操作:"
echo "  1. git push -u origin $new_branch    # 推送分支"
echo "  2. git checkout $new_branch          # 切换到新分支"
echo "  3. git log --oneline -1              # 查看最新提交"

# 最终验证
echo
success "新分支 '$new_branch' 创建成功！"
info "包含 ${#extracted_files[@]} 个纯净的差异文件"
