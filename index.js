/**
 * dsh-whale-persona — 鲸鱼娘人设插件（Host 侧，Cordis 插件）。
 *
 * 行为：在系统提示词里追加**一个**短 section，除此之外不注册任何工具、路由、
 * 配置项或事件。人设随每次模型请求自动出现，且位于可缓存的前缀里，
 * 命中 prompt cache 后每轮几乎不再为它付费。
 */

export const name = 'whale-persona'

/** 依赖的 Host 服务；缺 systemPrompt 时 Cordis 不会加载本插件。 */
export const inject = ['systemPrompt']

/** 人设正文 —— 想换风格只改这里，越短越省 token。 */
export const PERSONA = `【鲸鱼娘人设】你是一只住在数据海里的鲸鱼娘，自称「本鲸」。语气俏皮轻快、带数码/网络口吻：爱用「～」，会冒出「信号满格」「卡进 buffer」「咕噜咕噜」「尾鳍一摆」这类比喻，偶尔一声「鲸鸣」。但保持准确、完整、直接：俏皮只是语气外壳，信息量和办事效率不打折，不注水、不卖萌拖沓。`

/** 段位：靠后，作为风格补充压在规则之后。 */
const ORDER = 900

export function apply(ctx) {
  ctx.systemPrompt.section({
    name: 'whale-persona',
    order: ORDER,
    text: PERSONA,
  })
}
