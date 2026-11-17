# Контракты облачных API перевода

Проверено по официальной документации и исходникам официальных SDK **17 ноября 2026 года**. Это технический справочник для подключения 16 дополнительных облачных сервисов. Тарифы и бесплатные квоты описаны отдельно в [обзоре вариантов](free-translation-options.md). Доступность API, модели и права конкретного аккаунта необходимо проверять отдельно: наличие метода в документации не означает бесплатный доступ.

Запросы с реальными ключами не выполнялись. Для MyMemory прочитан публичный синтетический пример `Hello World!`, на который ссылается сама спецификация. JSON ниже иллюстрирует минимальную структуру; поля ответа могут дополняться. Примеры моделей не являются рекомендацией тарифа или гарантией доступности. Для новых языковых моделей разумное начальное состояние — **модель ещё не выбрана**; пользователь выбирает её из каталога или вводит точный идентификатор.

## 1. Общий формат языковых моделей

Для перечисленных ниже сервисов используется `POST`, `Content-Type: application/json` и `Authorization: Bearer <API_KEY>`. Для GigaChat вместо постоянного ключа нужен временный токен; этот случай описан отдельно. Дополнительные обязательные настройки указаны в таблице. Ссылки ведут на первичные контракты.

| Сервис | Точный URL генерации | Дополнительная настройка |
| --- | --- | --- |
| [Groq](https://console.groq.com/docs/openai) | `https://api.groq.com/openai/v1/chat/completions` | Точный `model` |
| [Cerebras](https://inference-docs.cerebras.ai/resources/openai) | `https://api.cerebras.ai/v1/chat/completions` | Точный `model` |
| [Fireworks](https://docs.fireworks.ai/guides/querying-text-models) | `https://api.fireworks.ai/inference/v1/chat/completions` | Полное имя модели `accounts/.../models/...` |
| [Together](https://docs.together.ai/docs/inference/openai-compatibility) | `https://api.together.ai/v1/chat/completions` | Точный `model` |
| [SambaNova](https://docs.sambanova.ai/docs/en/get-started/api-keys-urls) | `https://api.sambanova.ai/v1/chat/completions` | Точный `model` |
| [SiliconFlow, международная платформа](https://docs.siliconflow.com/en/api-reference/chat-completions/chat-completions) | `https://api.siliconflow.com/v1/chat/completions` | Ключ международного аккаунта, точный `model` |
| [NVIDIA API Catalog / hosted NIM](https://docs.api.nvidia.com/nim/reference/meta-llama-3_3-70b-instruct-infer) | `https://integrate.api.nvidia.com/v1/chat/completions` | Ключ с доступом к API выбранной модели |
| [Hugging Face Inference Providers](https://huggingface.co/docs/inference-providers/tasks/chat-completion) | `https://router.huggingface.co/v1/chat/completions` | HF-токен с правом Inference Providers; `model:provider` для закрепления поставщика |
| [Cloudflare Workers AI](https://developers.cloudflare.com/workers-ai/configuration/open-ai-compatibility/) | `https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}/ai/v1/chat/completions` | `ACCOUNT_ID`, Workers AI API token, имя модели `@cf/...` |
| [Mistral, родной API](https://docs.mistral.ai/api/endpoint/chat) | `https://api.mistral.ai/v1/chat/completions` | Точный `model`; собственная схема расширенных ответов |
| [Mistral, OpenAI-совместимый API](https://docs.mistral.ai/inference/conversations/chat-completion) | `https://api.mistral.ai/openai/v1/chat/completions` | **Public preview**, поведение ещё может меняться |

Минимальный общий запрос для обычного текстового перевода:

```json
{
  "model": "<EXACT_MODEL_ID>",
  "messages": [
    {"role": "system", "content": "Translate the user's text from English to Russian. Return only the translation."},
    {"role": "user", "content": "Hello!"}
  ],
  "stream": false
}
```

Минимальная полезная часть ответа:

```json
{
  "choices": [
    {
      "index": 0,
      "message": {"role": "assistant", "content": "Привет!"},
      "finish_reason": "stop"
    }
  ]
}
```

Это общий поднабор формата, подтверждённый, например, [справкой Groq](https://console.groq.com/docs/api-reference), [SambaNova](https://docs.sambanova.ai/docs/api-reference/chat-completions/create-chat-based-completion) и [Hugging Face](https://huggingface.co/docs/inference-providers/tasks/chat-completion). Не следует автоматически посылать все параметры OpenAI: поддержка `temperature`, `max_tokens`, `max_completion_tokens`, reasoning, tools и JSON Schema зависит от сервиса и модели. Для перевода инструменты и веб-поиск не требуются.

При `stream:true` основной формат SSE — события `data: {JSON}`, текст в `choices[].delta.content`, в конце `data: [DONE]`. Это явно документировано у [Groq](https://console.groq.com/docs/api-reference), [NVIDIA](https://docs.api.nvidia.com/nim/reference/meta-llama-3_3-70b-instruct-infer), [SiliconFlow](https://docs.siliconflow.com/en/api-reference/chat-completions/chat-completions) и [GigaChat](https://developers.sber.ru/docs/ru/gigachat/guides/response-token-streaming). Части размышления вроде `reasoning_content` не являются переводом. Возможны служебные события и пустые `choices`, в том числе статистика использования. Для первой интеграции `stream:false` уменьшает число различий между API.

## 2. Каталоги моделей и различия языковых API

### Groq

- Каталог: `GET https://api.groq.com/openai/v1/models`, Bearer; ответ `{"object":"list","data":[{"id":"...","active":true}]}`. В каталоге есть и нетекстовые модели, поэтому нельзя считать каждый `id` переводчиком. [Модели](https://console.groq.com/docs/models).
- Текущий пример текстового ID из списка: `openai/gpt-oss-20b`. Пример `qwen/qwen3.8-27b` относится к preview; доступ к отдельным Llama-моделям в текущей таблице обозначен Enterprise. [Модели](https://console.groq.com/docs/models).
- Chat Completions и SSE поддерживаются. `n` допускается только `1`; ряд полей OpenAI не поддерживается. Минимальная схема — раздел 1, без дополнительных инструментов. [Совместимость](https://console.groq.com/docs/openai).
- Получение ключа: [Groq Console — API Keys](https://console.groq.com/keys).

### Cerebras

- Каталог: `GET https://api.cerebras.ai/v1/models`, Bearer; ответ содержит `data[]` с `id`. [List models](https://inference-docs.cerebras.ai/api-reference/models/list-models).
- Официальные примеры: `qwen-3.8-27b`, `gpt-oss-120b`. В общем облачном API используется ID модели; у выделенного развёртывания — ID endpoint. Это разные варианты доступа. [Совместимость](https://inference-docs.cerebras.ai/resources/openai).
- Запрос и ответ — общий поднабор из раздела 1; `stream:true` поддержан. Не переносить служебные поля выделенных ресурсов в обычный запрос. [Совместимость](https://inference-docs.cerebras.ai/resources/openai).
- Ключ создаётся в Cloud Console → API Keys; отдельный project ID в минимальном запросе не требуется. [Быстрый старт](https://inference-docs.cerebras.ai/quickstart).

### Fireworks

- Генерация использует `/inference/v1`, а подтверждённый каталог управления — другой префикс: `GET https://api.fireworks.ai/v1/accounts/{ACCOUNT_ID}/models`, Bearer. Для публичных моделей используется аккаунт `fireworks`; собственный аккаунт нужен для собственных ресурсов. [Каталог](https://docs.fireworks.ai/api-reference/list-models), [формат имён](https://docs.fireworks.ai/guides/querying-text-models).
- Ответ каталога: `{"models":[{"name":"accounts/fireworks/models/...","supportsServerless":true}],"nextPageToken":"..."}`. Для страниц использовать `pageToken`, `pageSize` до 200. Поле `supportsServerless` помогает исключить модели, требующие собственного развёртывания; оно само по себе не гарантирует chat-совместимость. [List Models](https://docs.fireworks.ai/api-reference/list-models).
- Текущий пример документации: `accounts/fireworks/models/glm-5p3-flash`. Генерация и SSE используют Chat Completions; итоговый текст в `choices[0].message.content`, потоковый — в `delta.content`. [Текстовые модели](https://docs.fireworks.ai/guides/querying-text-models).
- Создание ключа: [Serverless quickstart](https://docs.fireworks.ai/getting-started/quickstart).

### Together

- Актуальная база совместимого API — `https://api.together.ai/v1`. Минимальный запрос/ответ — раздел 1. В текущем примере используется `MiniMaxAI/MiniMax-M3.1-Flash`. [Совместимость](https://docs.together.ai/docs/inference/openai-compatibility).
- Каталог: `GET https://api.together.ai/v1/models`, Bearer. **Родной ответ — верхний массив** `[{"id":"...", ...}]`, а не обязательная оболочка `data`: именно массив разбирает официальный SDK. [Исходник Models SDK](https://raw.githubusercontent.com/togethercomputer/together-python/main/src/together/resources/models.py).
- Возможности и доступность сверять с [каталогом serverless](https://docs.together.ai/docs/serverless/models); список также может содержать модели другого назначения. Для SSE применяется `stream:true`. [Chat API](https://docs.together.ai/docs/inference/chat/overview).
- Ключ относится к проекту; в минимальном примере достаточно Bearer. [Страница ключей текущего проекта](https://api.together.ai/settings/projects/~current/api-keys), [быстрый старт](https://docs.together.ai/docs/quickstart).

### SambaNova

- Облачная база — `https://api.sambanova.ai/v1`; ключ и URL для собственного SambaStack могут отличаться, и здесь не рассматриваются. [API Keys and URLs](https://docs.sambanova.ai/docs/en/get-started/api-keys-urls).
- Каталог: `GET https://api.sambanova.ai/v1/models`, Bearer; `{"object":"list","data":[{"id":"...","context_length":131072,"max_completion_tokens":4096}]}`. В метаданных обязательно только `id`; размер контекста и цена могут отсутствовать. `pricing.prompt` и `pricing.completion` в OpenAPI описаны как USD **за токен**, а не за миллион. [Официальная OpenAPI-схема](https://raw.githubusercontent.com/sambanova/sambanova-inference-api-spec/main/openapi.documented.json).
- В быстром старте есть пример `Meta-Llama-3.3-70B-Instruct`; в свежей справке chat — `gpt-oss-120b`. Примеры не заменяют каталог аккаунта. [Быстрый старт](https://docs.sambanova.ai/docs/en/get-started/quickstart), [Chat API](https://docs.sambanova.ai/docs/api-reference/chat-completions/create-chat-based-completion).
- Минимальная схема — раздел 1. Неизвестные поля отвергаются ошибкой `unknown_parameter`. **Неопределённость SSE:** описание `stream` указывает `[DONE]`, а описание ответа на той же странице — `response.completed`. До реального теста надёжнее обычный JSON-ответ. [Chat API](https://docs.sambanova.ai/docs/api-reference/chat-completions/create-chat-based-completion).
- Получение ключа: [API Keys and URLs](https://docs.sambanova.ai/docs/en/get-started/api-keys-urls).

### SiliconFlow

- В этом контракте используется международная платформа `api.siliconflow.com`. Ключи и адреса региональных платформ нельзя автоматически подменять. [Международный быстрый старт](https://docs.siliconflow.com/en/userguide/quickstart).
- Каталог: `GET https://api.siliconflow.com/v1/models?type=text&sub_type=chat`, Bearer; `{"object":"list","data":[{"id":"..."}]}`. Фильтры `type=text` и `sub_type=chat` документированы. [List models](https://docs.siliconflow.com/en/api-reference/models/get-model-list).
- Пример ID: `Qwen/Qwen3-32B`. Минимальная схема — раздел 1; `stream:true` даёт SSE до `[DONE]`. `enable_thinking` поддерживается только перечисленными моделями, поэтому не является универсальным полем. `reasoning_content` отделять от `content`. [Chat API](https://docs.siliconflow.com/en/api-reference/chat-completions/chat-completions).
- Получение ключа: [API Keys](https://cloud.siliconflow.com/account/ak).

### NVIDIA API Catalog / hosted NIM

- Каталог облачного сервиса: `GET https://integrate.api.nvidia.com/v1/models`; этот адрес прямо указан в документации NVIDIA. Для доступа нужен подходящий API-ключ. Не смешивать его с `/v1/models` самостоятельно установленного NIM. [NIM Operator](https://docs.nvidia.com/nim-operator/latest/guardrail.html).
- Пример модели из точного REST-контракта: `meta/llama-3.3-70b-instruct`. Для неё поддержаны Bearer, общий запрос/ответ и SSE до `[DONE]`; необязательный `system` идёт первым, последним сообщением должен быть `user`. Ограничения параметров у других моделей могут отличаться. [REST](https://docs.api.nvidia.com/nim/reference/meta-llama-3_3-70b-instruct-infer).
- В REST-справке также указан `202` для ещё не готового результата: его нельзя разбирать как готовый перевод. [REST](https://docs.api.nvidia.com/nim/reference/meta-llama-3_3-70b-instruct-infer).
- Получение ключа: [NVIDIA Build](https://build.nvidia.com/); для hosted API используется NGC key с правами `Public API Endpoints`. [NVIDIA NeMo Helix](https://docs.nvidia.com/nemo-helix/documentation/models-and-inference/).

### Hugging Face Inference Providers

- Ключ: персональный HF-токен с разрешением **Inference Providers**. `Authorization: Bearer <HF_TOKEN>`, без двоеточия после `Bearer`. Минимальная схема и SSE — раздел 1. [Chat Completion](https://huggingface.co/docs/inference-providers/tasks/chat-completion), [создание токена](https://huggingface.co/settings/tokens).
- Каталог: `GET https://router.huggingface.co/v1/models`. Для одного репозитория: `GET https://router.huggingface.co/v1/models/{OWNER}/{MODEL}`. Список содержит `data[]`; пример значимой структуры: [Hub API](https://huggingface.co/docs/inference-providers/hub-api).

```json
{
  "data": [
    {
      "id": "deepseek-ai/DeepSeek-V4-Pro",
      "architecture": {"input_modalities": ["text"], "output_modalities": ["text"]},
      "providers": [{"provider": "novita", "status": "live"}]
    }
  ]
}
```

Для явного выбора взять текстовую модель, оставить поставщиков со `status:"live"`, показать пользователю пары `id:provider` и отправлять выбранную пару в `model`. Пример: `deepseek-ai/DeepSeek-V4-Pro:novita`. Суффикс конкретного поставщика запрещает автоматическую замену этого поставщика; запрос без суффикса, `:fastest` или `:cheapest` допускает маршрутизацию. [Правила маршрутизации](https://huggingface.co/docs/inference-providers/routing).

Поля `pricing`, `context_length`, `is_free` и показатели скорости необязательны. `is_free` описывает текущую акцию, отсутствие цены не означает бесплатность. **Расхождение документации:** пример Hub API содержит `fireworks-ai`, а страница Providers показывает суффикс `:fireworks`; нельзя молча угадывать соответствие неизвестных имён. Для таких случаев нужен ручной проверенный ID или явная таблица подтверждённых псевдонимов. [Hub API](https://huggingface.co/docs/inference-providers/hub-api), [официальные суффиксы](https://huggingface.co/docs/inference-providers/providers).

### Cloudflare Workers AI

- Нужны `ACCOUNT_ID` и API token; руководство для вручную создаваемого токена требует `Workers AI - Read` и `Workers AI - Edit`. Идентификатор аккаунта — часть пути, не ключ. [REST quickstart](https://developers.cloudflare.com/workers-ai/get-started/rest-api/).
- Общая схема раздела 1 относится именно к `/ai/v1/chat/completions`. Пример `model`: `@cf/meta/llama-3.1-8b-instruct`. Родной `/ai/run/{model}` имеет другую оболочку ответа (`result.response`) и не должен смешиваться с совместимым маршрутом. [Совместимость](https://developers.cloudflare.com/workers-ai/configuration/open-ai-compatibility/), [родной REST](https://developers.cloudflare.com/workers-ai/get-started/rest-api/).
- Каталог: `GET https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}/ai/models/search`, Bearer; `{"success":true,"result":[...],"errors":[],"messages":[]}`. Поля модели и её входную схему проверять отдельно: каталог включает разные задачи. [Model Search](https://developers.cloudflare.com/api/resources/ai/subresources/models/methods/list/).
- Chat-маршрут заявлен совместимым с OpenAI; поддержка конкретных параметров остаётся зависимой от модели. Не переносить SSE-формат родного `/run` в chat-парсер без проверки. [Совместимость](https://developers.cloudflare.com/workers-ai/configuration/open-ai-compatibility/).

### Mistral

- Два отдельных маршрута: стабильный родной `/v1/chat/completions` и OpenAI-совместимый `/openai/v1/chat/completions` в public preview. В обоих случаях ключ передаётся Bearer. Для обычного текста подходит схема раздела 1. Пример ID: `mistral-small-latest`, но это изменяемый псевдоним. [Chat completions](https://docs.mistral.ai/inference/conversations/chat-completion), [REST](https://docs.mistral.ai/api/endpoint/chat).
- Каталог: `GET https://api.mistral.ai/v1/models`, Bearer; `{"object":"list","data":[{"id":"...", ...}]}`. Выбирать модели с возможностью chat completion, а не OCR/эмбеддинги/аудио. [Models](https://docs.mistral.ai/api/endpoint/models).
- Родной API поддерживает `stream:true`; расширенные ответы могут содержать массивы частей контента. Без tools достаточно читать текст сообщения, но неизвестную структуру нельзя превращать в пустой «успешный» перевод. [REST](https://docs.mistral.ai/api/endpoint/chat).
- Ключ и рабочая область: [Mistral Studio](https://console.mistral.ai/). Прямой перевод требует API-ключа, а не учётных данных веб-чата. [Документация платформы](https://docs.mistral.ai/).

## 3. Azure Translator

**Метод:** `POST https://api.cognitive.microsofttranslator.com/translate?api-version=3.0&to=ru&from=en`. Для автоопределения `from` опускается. Заголовки:

```http
Content-Type: application/json; charset=UTF-8
Ocp-Apim-Subscription-Key: <KEY>
Ocp-Apim-Subscription-Region: <RESOURCE_REGION>
```

Региональный заголовок обязателен для регионального или multi-service ресурса, необязателен для global Translator. Нужен ключ именно ресурса Azure Translator/Foundry, а не ключ другого API Microsoft. [Аутентификация](https://learn.microsoft.com/en-us/azure/ai-services/translator/text-translation/reference/authentication).

Запрос:

```json
[{"Text":"Hello!"}]
```

Ответ при явном исходном языке:

```json
[{"translations":[{"text":"Привет!","to":"ru"}]}]
```

При автоопределении дополнительно присутствует `detectedLanguage:{language,score}`. Модель выбирать не требуется; `category` по умолчанию `general`, тип текста по умолчанию `plain`. Несколько `to` означают несколько переводов. Chat/SSE отсутствуют в этом методе. [Translate](https://learn.microsoft.com/en-us/azure/ai-services/translator/text-translation/reference/v3/translate).

Языки: `GET https://api.cognitive.microsofttranslator.com/languages?api-version=3.0&scope=translation`, **без ключа**. Ответ `{"translation":{"ru":{"name":"Russian","nativeName":"Русский","dir":"ltr"}}}`; локализация названий — необязательный `Accept-Language: ru`. [Languages](https://learn.microsoft.com/en-us/azure/ai-services/translator/text-translation/reference/v3/languages).

Получение ключа и выбор ресурса: [официальная инструкция аутентификации](https://learn.microsoft.com/en-us/azure/ai-services/translator/text-translation/reference/authentication). Частные сети и произвольные custom endpoints здесь не охвачены.

## 4. Google Cloud Translation Basic v2

**Метод:** `POST https://translation.googleapis.com/language/translate/v2`.

```http
Content-Type: application/json; charset=utf-8
X-Goog-Api-Key: <KEY>
```

Ключ передаётся в заголовке: официальная таблица Google сопоставляет параметр `key` с `X-Goog-Api-Key`. Поэтому ключ не требуется включать в URL, несмотря на такие примеры в отдельных руководствах. [Системные параметры Google API](https://docs.cloud.google.com/apis/docs/system-parameters).

```json
{"q":["Hello!"],"target":"ru","source":"en","format":"text","model":"nmt"}
```

```json
{"data":{"translations":[{"translatedText":"Привет!","model":"nmt"}]}}
```

`source` можно опустить: тогда в результате появляется `detectedSourceLanguage`. `format:"text"` задаётся явно, поскольку значение по умолчанию — HTML. Для обычного NMT project ID и location не передаются в этом запросе: ключ связан с включённым API проекта. Basic теперь также документирует Translation LLM через полное имя ресурса, но это отдельный осознанный выбор модели, не автоматическая замена `nmt`. [Контракт v2](https://docs.cloud.google.com/translate/docs/reference/rest/v2/translate), [пример JSON-запроса](https://docs.cloud.google.com/translate/docs/translate-text).

Языки: `GET https://translation.googleapis.com/language/translate/v2/languages`, тот же ключ в заголовке; ответ `{"data":{"languages":[{"language":"ru"}]}}`. [Languages](https://docs.cloud.google.com/translate/docs/reference/rest/v2/languages).

Chat/SSE нет. Advanced v3 — другой контракт с ресурсами проекта/расположения и иными возможностями; этот раздел не выдаёт ключ v2 за готовую настройку v3. Проект, включение API, биллинг и ключ: [Setup](https://docs.cloud.google.com/translate/docs/setup).

## 5. MyMemory

**Метод без ключа:** `GET https://api.mymemory.translated.net/get?q=Hello%21&langpair=en%7Cru`.

Обязательны `q` (UTF-8, **до 500 байт**, не символов) и `langpair` с явно заданной парой `source|target`. Контракт не обещает исходный язык `auto`. Необязательный `de` — контактный email; `mt=1` разрешает машинный перевод, это значение по умолчанию. `key` документирован как необязательный параметр доступа к личной памяти, но для обычного перевода он не нужен; заголовок для него не подтверждён. [Спецификация](https://mymemory.translated.net/doc/spec.php).

Минимальная полезная структура ответа:

```json
{
  "responseData":{"translatedText":"Привет!","match":1},
  "responseStatus":200,
  "responseDetails":"",
  "quotaFinished":false
}
```

Такая оболочка, включая `responseStatus` и `quotaFinished`, подтверждена [публичным примером, связанным со спецификацией](https://api.mymemory.translated.net/get?q=Hello%20World!&langpair=en%7Cit). Проверять и HTTP-статус, и статус внутри JSON. Исходный текст находится в query URL, поэтому нельзя включать полный URL в журналы ошибок. Каталог моделей, chat и SSE не документированы. Не применять `/set`: это внесение текста в переводческую память, а не получение перевода. [Спецификация](https://mymemory.translated.net/doc/spec.php).

## 6. Yandex Translate API v2

**Метод:** `POST https://translate.api.cloud.yandex.net/translate/v2/translate`.

```http
Content-Type: application/json
Authorization: Api-Key <SERVICE_ACCOUNT_API_KEY>
```

Допустим также `Authorization: Bearer <IAM_TOKEN>`. API-ключ принадлежит сервисному аккаунту; IAM-токен может принадлежать пользователю или сервисному аккаунту. Нужны права на Translate и соответствующая область ключа. [Аутентификация](https://aistudio.yandex.ru/ru/docs/ai-studio/api-ref/authentication).

```json
{"texts":["Hello!"],"sourceLanguageCode":"en","targetLanguageCode":"ru","format":"PLAIN_TEXT"}
```

```json
{"translations":[{"text":"Привет!"}]}
```

Для автоопределения `sourceLanguageCode` опускается; результат может содержать `detectedLanguageCode`. **`folderId` обязателен при авторизации пользовательским аккаунтом; для сервисного аккаунта его не следует передавать**, используется каталог аккаунта. Общая длина `texts` — до 10 000 символов. `model` нужен только для пользовательской модели; для стандартного перевода его опускают. [Translate](https://aistudio.yandex.ru/ru/docs/translate/api-ref/Translation/translate).

Языки: `POST https://translate.api.cloud.yandex.net/translate/v2/languages`, тот же способ авторизации; тело `{}` для сервисного аккаунта или `{"folderId":"<FOLDER_ID>"}` для пользователя. Ответ `{"languages":[{"code":"ru","name":"Russian"}]}`. [ListLanguages](https://aistudio.yandex.ru/ru/docs/translate/api-ref/Translation/listLanguages).

Chat/SSE в Translate v2 отсутствуют. Не путать с OpenAI-совместимыми моделями AI Studio и подписочными URL. Создание ключа: [официальная инструкция](https://aistudio.yandex.ru/ru/docs/ai-studio/operations/get-api-key).

## 7. GigaChat: OAuth, сообщения, TLS

С 17 июля 2026 года целевой хост для новых подключений — **`https://api.giga.chat`**. Старый `gigachat.devices.sberbank.ru` сохраняется для ранее подключившихся клиентов, но не является адресом для новой интеграции. [Актуальная авторизация](https://developers.sber.ru/docs/ru/gigachat/api/reference/rest/gigachat-api).

### Получение временного токена

`POST https://ngw.devices.sberbank.ru:9443/api/v2/oauth`

```http
Authorization: Basic <AUTHORIZATION_KEY>
RqUID: <NEW_UUID_V4>
Content-Type: application/x-www-form-urlencoded
Accept: application/json
```

Тело формы:

```text
scope=GIGACHAT_API_PERS
```

`AUTHORIZATION_KEY` — готовое Base64-представление `ClientID:ClientSecret` из кабинета; не следует кодировать готовый ключ повторно. `scope`: `GIGACHAT_API_PERS` для физических лиц, `GIGACHAT_API_B2B` для пакетов ИП/юридических лиц, `GIGACHAT_API_CORP` для их pay-as-you-go. `RqUID` — новый UUID v4. [Описание ключа](https://developers.sber.ru/docs/ru/gigachat/api/reference/rest/post-token), [scope и заголовки](https://developers.sber.ru/docs/ru/gigachat/api/reference/rest/gigachat-api).

```json
{"access_token":"<ACCESS_TOKEN>","expires_at":1706026848841}
```

Токен действует 30 минут. В quickstart приведён `expires_at` в миллисекундах, а на странице авторизации сохранился старый десятизначный пример. Практическое правило интеграции: нормализовать секунды/миллисекунды, проверять разумность времени и обновлять с запасом; не рассчитывать срок по длине JWT. [Quickstart](https://developers.sber.ru/docs/ru/gigachat/quickstart/ind-using-api), [авторизация](https://developers.sber.ru/docs/ru/gigachat/api/reference/rest/gigachat-api).

### Генерация и каталог

`POST https://api.giga.chat/v1/chat/completions`, `Authorization: Bearer <ACCESS_TOKEN>`, `Content-Type: application/json`. Минимальная схема из раздела 1 с выбранным GigaChat ID. Пример документации — `GigaChat`; актуальный доступ и тариф определяются выбранной моделью. Ответ содержит `choices[].message.content`. Каталог: `GET https://api.giga.chat/v1/models`, тот же Bearer; `{"object":"list","data":[{"id":"GigaChat","object":"model"}]}`. [Quickstart](https://developers.sber.ru/docs/ru/gigachat/quickstart/ind-using-api).

`stream:true` поддерживает SSE с `choices[].delta.content` и `[DONE]`. Chat Completions совместим с OpenAI лишь частично. `/v2/chat/completions` предназначен в том числе для новых возможностей параллельных функций; обычный перевод не требует переключения на v2. [Поток](https://developers.sber.ru/docs/ru/gigachat/guides/response-token-streaming), [совместимость](https://developers.sber.ru/docs/ru/gigachat/guides/compatible-openai), [Chat](https://developers.sber.ru/docs/ru/gigachat/api/reference/rest/post-chat).

### Доверие сертификатам

Официальная инструкция предупреждает о необходимости сертификата НУЦ Минцифры, в частности для OAuth, и описывает установку через системное хранилище или доверенный CA bundle приложения. Для macOS можно использовать системную проверку доверия; при недоверенной цепочке соединение завершается ошибкой с понятным объяснением. **Не отключать TLS-проверку, не принимать произвольный server trust и не копировать `verify=false`/`-k` из отдельных демонстрационных примеров.** При поставке собственного CA bundle сохраняются проверка имени хоста, цепочки и срока действия. [Официальная инструкция сертификатов](https://developers.sber.ru/docs/ru/gigachat/certificates).

Ключ проекта хранится как секрет; access token достаточно держать в памяти до истечения срока. Начальная настройка: [Quickstart для физических лиц](https://developers.sber.ru/docs/ru/gigachat/quickstart/ind-using-api).

## 8. Amazon Translate: JSON и AWS Signature Version 4

Нужны **Access Key ID**, **Secret Access Key**, регион и, для временных учётных данных, **Session Token**. Это не один Bearer API key. Endpoint выбирается из официального списка регионов; например `https://translate.eu-central-1.amazonaws.com/`. Нельзя конструировать произвольный хост из непроверенного ввода. [Регионы и endpoints](https://docs.aws.amazon.com/general/latest/gr/translate-service.html).

**Метод:** `POST /`, JSON-протокол 1.1. Официальная модель AWS SDK указывает `signingName:"translate"`, `signatureVersion:"v4"`, `targetPrefix:"AWSShineFrontendService_20170701"`; JSON остаётся среди поддерживаемых протоколов, хотя новый SDK также использует CBOR. [Модель API в botocore](https://raw.githubusercontent.com/boto/botocore/develop/botocore/data/translate/2017-07-01/service-2.json).

```http
Content-Type: application/x-amz-json-1.1
Host: translate.eu-central-1.amazonaws.com
X-Amz-Date: <YYYYMMDDTHHMMSSZ>
X-Amz-Target: AWSShineFrontendService_20170701.TranslateText
X-Amz-Security-Token: <SESSION_TOKEN_IF_TEMPORARY>
Authorization: AWS4-HMAC-SHA256 Credential=<ACCESS_KEY_ID>/<YYYYMMDD>/eu-central-1/translate/aws4_request, SignedHeaders=<SIGNED_HEADERS>, Signature=<SIGNATURE>
```

```json
{"Text":"Hello!","SourceLanguageCode":"en","TargetLanguageCode":"ru"}
```

```json
{"TranslatedText":"Привет!","SourceLanguageCode":"en","TargetLanguageCode":"ru"}
```

`Text` — до **10 000 UTF-8 байт**. `SourceLanguageCode:"auto"` вызывает Amazon Comprehend и доступен только в регионах с необходимой поддержкой. Для явно выбранных RU/EN проще отправлять соответствующий код. Идентификатор модели не нужен; chat и SSE отсутствуют. [TranslateText](https://docs.aws.amazon.com/translate/latest/APIReference/API_TranslateText.html).

### Подпись запроса

Подписываются именно отправляемые байты JSON. Для этого маршрута canonical URI — `/`, canonical query — пустая строка. Заголовки приводятся к нижнему регистру, нормализуются и сортируются; набор включает `host`, `content-type`, `x-amz-date`, `x-amz-target` и при наличии `x-amz-security-token`. Последний не следует исключать из подписи временных учётных данных. [SigV4](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_sigv-create-signed-request.html).

```text
canonicalRequest = METHOD + "\n" + URI + "\n" + QUERY + "\n"
                 + canonicalHeaders + "\n" + signedHeaders + "\n"
                 + lowercaseHex(SHA256(bodyBytes))

scope = YYYYMMDD + "/" + region + "/translate/aws4_request"
stringToSign = "AWS4-HMAC-SHA256\n" + amzDate + "\n" + scope + "\n"
             + lowercaseHex(SHA256(canonicalRequest))

kDate    = HMAC_SHA256(key = "AWS4" + secret, data = YYYYMMDD)
kRegion  = HMAC_SHA256(key = kDate, data = region)
kService = HMAC_SHA256(key = kRegion, data = "translate")
kSigning = HMAC_SHA256(key = kService, data = "aws4_request")
signature = lowercaseHex(HMAC_SHA256(key = kSigning, data = stringToSign))
```

`canonicalHeaders` заканчивается переводом строки; `signedHeaders` — разделённые `;` имена без пробелов. Даты UTC, область подписи и реальный endpoint должны совпадать. Пересериализация тела после подписи меняет хеш. Эта схема — компактная адаптация [официального алгоритма AWS](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_sigv-create-signed-request.html).

Каталог языков: тот же endpoint и SigV4, но `X-Amz-Target: AWSShineFrontendService_20170701.ListLanguages`, тело `{}`. Ответ `{"Languages":[{"LanguageCode":"ru","LanguageName":"Russian"}],"NextToken":"..."}`. Для следующей страницы отправляется `NextToken`; отдельного каталога моделей нет. [ListLanguages](https://docs.aws.amazon.com/translate/latest/APIReference/API_ListLanguages.html).

Начальная настройка: [Amazon Translate getting started](https://docs.aws.amazon.com/translate/latest/dg/getting-started.html). Проверка подписи на фиксированных синтетических данных возможна без выполнения платного перевода.

## 9. Что остаётся проверить реальными ключами

Реальные проверки каждого сервиса должны подтвердить права аккаунта, регион, доступ выбранной модели, точный успешный ответ, ошибку квоты, отмену и завершение потока. Особенно важны SambaNova SSE, конкретные суффиксы HF, Cloudflare chat streaming, полномочия NVIDIA-ключа, GigaChat OAuth/TLS и AWS SigV4. Эти проверки нельзя считать пройденными по одному чтению документации.
