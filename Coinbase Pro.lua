-- Inofficial Coinbase Pro Extension (https://pro.coinbase.com/) for MoneyMoney
-- Fetches balances via Coinbase Pro API and returns them as securities
--
-- Username: Coinbase Pro API Key
-- Username2: Coinbase Pro API Secret
-- Password: Coinbase Pro API Passphrase
--
-- Copyright (c) 2017 Leo Schweizer
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
        version = 1.1,
        url = "https://api.pro.coinbase.com",
        description = "Fetch balances via Coinbase Pro API and list them as securities",
        services = { "Coinbase Pro" }
}

local apiKey
local apiSecret
local apiPassphrase

local nativeCurrency = "EUR"
local market = "Coinbase Pro"

function SupportsBank (protocol, bankCode)
        return protocol == ProtocolWebBanking and bankCode == "Coinbase Pro"
end

function InitializeSession (protocol, bankCode, username, username2, password, username3)
        apiKey = username
        apiSecret = username2
        apiPassphrase = password
end

function ListAccounts (knownAccounts)
        local account = {
                name = market,
                accountNumber = "Main",
                currency = nativeCurrency,
                portfolio = true,
                type = "AccountTypePortfolio"
        }
        return {account}
end

function RefreshAccount (account, since)
        local s = {}
        local balances = queryCoinbaseProApi("accounts")
        local products = queryCoinbaseProApi("products")
        for key, value in pairs(balances) do
                local balanceCurrency = value["currency"]
                local balanceAvailable = tonumber(value["available"]) > 0
                local securityCurrency = nil
                local price = nil
                local amount = nil
                local quantity = nil
                if balanceCurrency == nativeCurrency then
                        s[#s+1] = {
                                name = value["currency"],
                                market = market,
                                currency = balanceCurrency,
                                quantity = quantity,
                                price = price,
                                amount = value["balance"]
                        }
                else
                        local product_id = balanceCurrency .. '-' .. nativeCurrency
                        if productsExistsAndOnline(product_id, products) and (balanceAvailable == true) then
                                s[#s+1] = {
                                        name = value["currency"],
                                        market = market,
                                        currency = securityCurrency,
                                        quantity = value["balance"],
                                        price = queryExchangeRate(product_id),
                                        amount = amount
                                }
                        end
                end
        end
        return {securities = s}
end

function EndSession ()
end

function base64decode(data)
        local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
        data = string.gsub(data, '[^'..b..'=]', '')
        return (data:gsub('.', function(x)
                if (x == '=') then return '' end
                local r,f='',(b:find(x)-1)
                for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
                return r;
        end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
                if (#x ~= 8) then return '' end
                local c=0
                for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
                return string.char(c)
        end))
end

function queryCoinbaseProApi(endpoint)
        local path = string.format("/%s", endpoint)
        local timestamp = string.format("%d", MM.time())
        local apiSign = MM.hmac256(base64decode(apiSecret), timestamp .. "GET" .. path)

        local headers = {}
        headers["CB-ACCESS-KEY"] = apiKey
        headers["CB-ACCESS-TIMESTAMP"] = timestamp
        headers["CB-ACCESS-SIGN"] = MM.base64(apiSign)
        headers["CB-ACCESS-PASSPHRASE"] = apiPassphrase

        local content = Connection():request("GET", url .. path, nil, nil, headers)
        return JSON(content):dictionary()
end

function queryExchangeRate(product_id)
        return queryCoinbaseProApi("products/" .. product_id .. "/ticker")["price"]
end

function productsExistsAndOnline(product_id, products)
        for _, data in pairs(products) do
                local productExists = data["id"] == product_id
                local productOnline = data["status"] == "online"
                if (productExists == true) and (productOnline == true) then return true end
        end
        return false
end

-- SIGNATURE: MC0CFEG8subcDGgx/zTD7J/1tZqFZzwHAhUAml+4P1Ykr5zy+8ZerTz6I4AKsqQ=
