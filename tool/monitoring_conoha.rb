require 'net/https'
require 'uri'
require 'json'

# ConoHaAPI ユーザー名
CONOHA_API_USER = '*****'.freeze
# ConoHaAPI ユーザーパスワード
CONOHA_API_KEY = '*****'.freeze
# ConoHaAPI テナントID
CONOHA_API_TENANT = '*****'.freeze
# ConoHaAPI Identity API (トークン発行)
CONOHA_API_TOKEN_URL = 'https://identity.tyo1.conoha.io/v2.0/tokens'.freeze
# ConoHaAPI ObjectStorage API
CONOHA_API_STORAGE_URL = 'https://object-storage.tyo1.conoha.io/v1/nc_'.freeze

def conoha_api_token
  # アクセスするためのURLを生成
  uri = URI.parse(CONOHA_API_TOKEN_URL)
  https = https_config(uri)
  req = Net::HTTP::Post.new(uri.path)

  req.body = JSON.generate(api_param)

  # リクエスト送信
  res = https.start do |x|
    x.request(req)
  end

  # 取得したJSON形式のレスポンスをオブジェクトに変換
  JSON.parse(res.body)['access']['token']['id']
end

def https_config(uri)
  # HTTPSを使うための設定
  https = Net::HTTP.new(uri.host, uri.port)
  https.use_ssl = true
  https.verify_mode = OpenSSL::SSL::VERIFY_NONE
  https
end

def api_param
  # 送信するパラメータを設定
  {
    'auth' => {
      'passwordCredentials' => {
        'username' => CONOHA_API_USER,
        'password' => CONOHA_API_KEY
      },
      'tenantId' => CONOHA_API_TENANT
    }
  }
end

def storage_capacity(api_token)
  # アクセスするためのURLを生成
  uri = URI.parse(CONOHA_API_STORAGE_URL + CONOHA_API_TENANT)
  https = https_config(uri)
  req = Net::HTTP::Get.new(uri.path)

  req['Accept'] = 'application/json'
  # トークンIDを設定
  req['X-Auth-Token'] = api_token

  # リクエスト送信
  res = https.start do |x|
    x.request(req)
  end
  calculate_usage(res)
end

def calculate_usage(res)
  # 使用率を算出
  used_storage = res['x-account-bytes-used'].to_i / 1_073_741_824
  max_storage = res['x-account-meta-quota-bytes'].to_i / 1_073_741_824
  proportion = ((used_storage.to_f / max_storage.to_f) * 100).round

  # Slackに通知するメッセージを整形
  message_header = if proportion >= 80
    # ディスク使用率が80％以上に達した時は、メンション付きで、さらに強調して通知
    %(<!here>*【現在、ConoHaのディスク容量が少なくなってきています！対応をお願いします！！】*)
  else
    %(【現在のConoHaのディスク容量をお知らせします】)
  end

  %(#{message_header}
    容量: #{max_storage} G / 使用中: #{used_storage} G
    *使用率: #{proportion} %*)
end

# Webhook URL
SLACK_HOOK = 'https://hooks.slack.com/services/*****/*****/*****'.freeze

def send_slack(message)
  uri = URI.parse(SLACK_HOOK)
  payload = {
    text: message
  }
  Net::HTTP.post_form(uri, payload: payload.to_json)
end

api_token = conoha_api_token
message = storage_capacity(api_token)
send_slack(message)
