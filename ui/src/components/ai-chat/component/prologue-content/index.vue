<template>
  <!-- 开场白组件 -->
  <div class="item-content mb-16">
    <div class="avatar mr-8" v-if="prologue && showAvatar">
      <img v-if="application.avatar" :src="application.avatar" height="28px" width="28px" />
      <LogoIcon v-else height="28px" width="28px" />
    </div>
    <div
      class="content"
      v-if="prologue"
      :style="{
        'padding-right': showUserAvatar ? 'var(--padding-left)' : '0',
      }"
    >
      <el-card shadow="always" class="border-r-8" style="--el-card-padding: 10px 16px 12px">
        <MdRenderer
          :source="prologue"
          :send-message="sendMessage"
          reasoning_content=""
          :type="type"
        ></MdRenderer>
      </el-card>
    </div>
  </div>
</template>
<script setup lang="ts">
import { type chatType } from '@/api/type/application'
import { computed } from 'vue'
import MdRenderer from '@/components/markdown/MdRenderer.vue'
import { t } from '@/locales'
import useStore from '@/stores'
const props = defineProps<{
  application: any
  available: boolean
  type: 'log' | 'ai-chat' | 'debug-ai-chat'
  sendMessage: (question: string, other_params_data?: any, chat?: chatType) => void
}>()

const showAvatar = computed(() => {
  return props.application.show_avatar == undefined ? true : props.application.show_avatar
})
const showUserAvatar = computed(() => {
  return props.application.show_user_avatar == undefined ? true : props.application.show_user_avatar
})

const toQuickQuestion = (match: string, offset: number, input: string) => {
  return `<quick_question>${match.replace('- ', '')}</quick_question>`
}
const updatedPrologue = (prologue) => {
  const lang = new URL(window.location.href).searchParams.get('lang')
  if (lang) {
    if ('shipsage' in props.application?.desc) {
      if ('zh-CN' === lang) {
        prologue = 'Hello, I am the ShipSage assistant. You can ask me about ShipSage usage questions.\n- What are the main functions of ShipSage?\n- How to upload order?\n- What is VAS?'
      } else {
        prologue = "您好，我是ShipSage小助手。您可以咨询我关于ShipSage的使用问题。\n- ShipSage的主要功能有哪些？\n- 如何上传订单？\n- 什么是VAS？"
      }
    } else {
      if ('zh-CN' === lang) {
        prologue = 'Hello, I am the ai assistant. Could I help you?.'
      } else {
        prologue = "您好，我是AI小助手。需要我帮你帮你吗？"
      }
    }
  }

  return prologue
}
const prologue = computed(() => {
  let temp = props.available ? props.application?.prologue : t('chat.tip.prologueMessage')
  if (temp) {
    temp = updatedPrologue(temp)
    const tag_list = [
      /<html_rander>[\d\D]*?<\/html_rander>/g,
      /<echarts_rander>[\d\D]*?<\/echarts_rander>/g,
      /<quick_question>[\d\D]*?<\/quick_question>/g,
      /<form_rander>[\d\D]*?<\/form_rander>/g,
    ]
    let _temp = temp
    for (const index in tag_list) {
      _temp = _temp.replaceAll(tag_list[index], '')
    }
    const quick_question_list = _temp.match(/-\s.+/g)
    let result = temp
    for (const index in quick_question_list) {
      const quick_question = quick_question_list[index]
      result = result.replace(quick_question, toQuickQuestion)
    }
    return result
  }
  return ''
})
</script>
<style lang="scss" scoped></style>
