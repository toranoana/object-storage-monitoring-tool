require 'net/https'
require 'uri'
require 'json'

CONOHA_API_USER = '************'
CONOHA_API_KEY = '************'
CONOHA_API_TENANT = '**************'
SLACK_HOOK = '***********'

def conoha_api_token
  # アクセスするためのURLを生成
  base_url = 'https://identity.tyo1.conoha.io/v2.0/tokens'
  uri = URI.parse(base_url)

  # HTTPSを使うための設定
  https = Net::HTTP.new(uri.host, uri.port)
  https.use_ssl = true
  https.verify_mode = OpenSSL::SSL::VERIFY_NONE
  req = Net::HTTP::Post.new(uri.path)

  # 送信するパラメータ
  params = {
    'auth' => {
      'passwordCredentials' => {
        'username' => CONOHA_API_USER,
        'password' => CONOHA_API_KEY
      },
      'tenantId' => CONOHA_API_TENANT
    }
  }
  req.body = JSON.generate(params)

  # リクエスト送信
  res = https.start do |x|
    x.request(req)
  end

  # 取得したJSON形式のレスポンスをオブジェクトに変換
  result = JSON.parse(res.body)
  result['access']['token']['id']
end

def storage_capacity(api_token)
  # アクセスするためのURLを生成
  base_url = 'https://object-storage.tyo1.conoha.io/v1/nc_' + CONOHA_API_TENANT
  uri = URI.parse(base_url)

  # HTTPSを使うための設定
  https = Net::HTTP.new(uri.host, uri.port)
  https.use_ssl = true
  https.verify_mode = OpenSSL::SSL::VERIFY_NONE
  req = Net::HTTP::Get.new(uri.path)
  req['Accept'] = 'application/json'
  # トークンIDを設定
  req['X-Auth-Token'] = api_token

  # リクエスト送信
  res = https.start do |x|
    x.request(req)
  end

  # 使用率を算出
  used_storage = res['x-account-bytes-used'].to_i / 1_073_741_824
  max_storage = res['x-account-meta-quota-bytes'].to_i / 1_073_741_824
  proportion = (used_storage.to_f / max_storage.to_f) * 100
  proportion = proportion.round

  # Slackに通知するメッセージを整形
  if proportion >= 80
  # ディスク使用率が80％以上に達した時は、メンション付きで、さらに強調して通知
    message_header = '<!here>*【現在、ConoHaのディスク容量が少なくなってきています！対応をお願いします！！】*'
  else
    message_header = '【現在のConoHaのディスク容量をお知らせします】'
  end

 message_header + '\n容量: ' + max_storage.to_s + 'G / 使用中: ' + used_storage.to_s + 'G
  *使用率: ' + proportion.to_s + '%*'
end

def send_slcak(message)
  uri = URI.parse(SLACK_HOOK)
  payload = {
    text: message
  }
  Net::HTTP.post_form(uri, payload: payload.to_json)
end

api_token = conoha_api_token
message = storage_capacity(api_token)
send_slcak(message)
