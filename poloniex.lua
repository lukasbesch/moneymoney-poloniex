-- Inofficial Poloniex Extension (https://poloniex.com) for MoneyMoney
-- Fetches balances from Poloniex API and returns them as securities
--
-- Username: Poloniex API Key
-- Password: Poloniex API Secret
--
-- Copyright (c) 2018 Lukas Besch
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

WebBanking {
  version     = 0.1,
  url         = "https://poloniex.com/tradingApi",
  description = "Fetch balances from Poloniex API and list them as securities",
  services    = { "Poloniex Account" }
}

local apiKey
local apiSecret
local balances
local currency
local connection = Connection()

local currencySymbols = {
}

function SupportsBank (protocol, bankCode)
  return protocol == ProtocolWebBanking and bankCode == "Poloniex Account"
end

function InitializeSession (protocol, bankCode, username, username2, password, username3)
  apiKey = username
  apiSecret = password
  currency = "EUR"
end

function ListAccounts (knownAccounts)
  local account = {
    name = market,
    accountNumber = "Poloniex Account",
    currency = currency,
    portfolio = true,
    type = "AccountTypePortfolio"
  }

  return {account}
end

function RefreshAccount (account, since)
  balances = queryPrivate("returnBalances")

  local eurPrices = queryCryptoCompare("pricemulti", "?fsyms=" .. assetPrices() .. "&tsyms=EUR")
  local fallbackTable = {}
  fallbackTable["EUR"] = 0

  local s = {}
  for key, value in pairs(balances) do
    if tonumber(value) > 0 then
      s[#s+1] = {
        name = key,
        market = market,
        currency = nil,
        quantity = value,
        price = (eurPrices[symbolForAsset(key)] or fallbackTable)["EUR"],
      }
    end
  end

  return {securities = s}
end

function symbolForAsset(asset)
  return currencySymbols[asset] or asset
end

function assetPrices()
  local assets = ""
  for key, value in pairs(balances) do
    if tonumber(value) > 0 then
      assets = assets .. symbolForAsset(key) .. ','
    end
  end
  return assets
end

function EndSession ()
end

function bin2hex(s)
 return (s:gsub(".", function (byte)
   return string.format("%02x", string.byte(byte))
 end))
end


function httpBuildQuery(params)
  local str = ''
  for key, value in pairs(params) do
    str = str .. key .. "=" .. value .. "&"
  end
  return str.sub(str, 1, -2)
end

function queryPrivate(command)
  local nonce = string.format("%d", MM.time() * 1000)
  local request = {};
  request.command = "returnBalances"
  request.nonce = nonce;

  local postContent = httpBuildQuery(request)
  local apiSign = bin2hex(MM.hmac512(apiSecret, postContent))

  local headers = {}
  headers["Key"] = apiKey
  headers["Sign"] = apiSign
  headers["Content-Type"] = "application/x-www-form-urlencoded"
  headers["accept"] = "application/json"

  local content = connection:request("POST", url, postContent, "", headers)

  json = JSON(content)

  return json:dictionary()
end

function queryCryptoCompare(method, query)
  local path = string.format("/%s/%s", "data", method)

  connection = Connection()
  content = connection:request("GET", "https://min-api.cryptocompare.com" .. path .. query)
  json = JSON(content)

  return json:dictionary()
end
