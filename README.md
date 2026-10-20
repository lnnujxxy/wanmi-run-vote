# 万米跑报名投票 · 上线说明

一个可直接发到公网的投票页：手机打开即投，数据实时写入 Supabase 云数据库，页面自带实时统计看板。

- `index.html` —— 投票页面（投票表单 + 实时统计 + 名单），纯静态，零外部依赖
- `setup.sql` —— 数据库建表脚本
- `README.md` —— 本文件

---

## 一、建数据库（约 3 分钟）

1. 打开 <https://supabase.com> 注册账号（GitHub 登录最快），免费套餐足够用。
2. 点 **New project**，名字随便填（如 `wanmi-vote`），区域选 **Southeast Asia (Singapore)** 或 **Tokyo**（离国内近，延迟低），密码随便设一个存好。
3. 等约 2 分钟项目创建完成 → 左侧菜单 **SQL Editor** → **New query**。
4. 把 `setup.sql` 里的内容整段粘贴进去，点 **Run**。看到 `Success. No rows returned` 就成了。

## 二、拿密钥并填进页面

1. 左侧 **Project Settings**（齿轮图标）→ **API**。
2. 复制两个值：
   - **Project URL** → 形如 `https://abcdefgh.supabase.co`
   - **Project API keys → anon public** → 一长串 `eyJhbGci...`
3. 用编辑器打开 `index.html`，翻到最下面的 `<script>`，改这两行：

```js
var SUPABASE_URL = 'https://abcdefgh.supabase.co';   // 换成你的 Project URL
var SUPABASE_ANON_KEY = 'eyJhbGci...';               // 换成你的 anon public key
```

> `anon` 是公开可用的匿名密钥，设计上就允许写在前端页面里，泄露无风险。
> 真正要保密的是 `service_role` 那串，**不要**用在页面上。

## 三、发布到公网

### 方式 A：CloudStudio（本环境原生，一步到位）

直接让 WorkBuddy 重新执行部署即可（本次尝试时该服务暂时不可用，稍后重试即可）。

### 方式 B：Netlify Drop（不用注册，30 秒）

打开 <https://app.netlify.com/drop>，把 `index.html` 往页面里一拖，立刻拿到 `https://xxx.netlify.app` 链接。

### 方式 C：Vercel（国内访问较稳）

<https://vercel.com/new> → 选 **Deploy without Git** → 拖入文件。

### 方式 D：腾讯云 EdgeOne Pages（国内速度最快，需备案域名）

<https://edgeone.ai/products/pages> → 从本地上传静态文件。

> 国内访问优先选 D 或 C，图快选 B。

---

## 四、看数据与导出

Supabase 左侧 **Table Editor** → `votes` 表，可以像 Excel 一样直接看、直接改、直接导出 CSV。

常用 SQL（在 SQL Editor 里跑）：

```sql
-- 看当前统计结果
select * from public.vote_stats();

-- 导出参加者名单（可直接复制成 Excel）
select dept, name, note, created_at
from public.latest_votes
where choice = 'join'
order by dept, name;

-- 看某人的改票轨迹
select choice, note, created_at from public.votes
where name = '张三' order by created_at;

-- 清空重来
truncate table public.votes restart identity;
```

---

## 五、规则说明

| 项目 | 说明 |
| --- | --- |
| 身份判定 | **姓名 + 部门**两个都一致才算同一个人 |
| 改票 | 用同样的姓名和部门再投一次，以最新一次为准 |
| 防篡改 | 数据库只开放「新增」和「读取」权限，任何人无法删除或修改已投的票 |
| 历史留存 | 每次投票都留一条记录，改票轨迹完整可查 |
| 刷新频率 | 统计每 20 秒自动更新，提交后立即刷新 |

## 六、常见问题

**页面顶部出现黄色「还没接数据库」提示？**
说明 `index.html` 里还是占位符。按第二步填好 URL 和 key，重新发布一次即可。

**提交时提示「提交失败：401 / 401 Unauthorized」？**
key 复制错了，或者复制成了 `service_role`。确认用的是 **anon public**。

**提交时提示「提交失败：404」？**
`setup.sql` 没执行成功，或者执行在别的项目里。回 SQL Editor 确认 `votes` 表存在。

**能防一个人刷票吗？**
同一个人（姓名+部门一致）重复投票只会覆盖自己的票，不会重复计数。跨设备刷同名的行为无法完全杜绝——内部活动靠自觉即可；如果需要强校验，可以在页面加手机号验证码，成本高不少。

**想改选项文字、活动信息、截止时间？**
直接改 `index.html`：活动信息在 `<div class="hero">` 里，选项文字搜 `class="choice"` 那三块。
