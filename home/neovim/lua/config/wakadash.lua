local curl = require('plenary.curl')

local res = curl.request {
  url = "https://wakatime.com/api/v1/users/current/status_bar/today",
  method = "get",
  accept = "application/json",
  headers = {
    authorization = "Basic d2FrYV9jMWE1OTYyMC01OTNjLTRhZjYtYTFiNi1jZWYxZjlmYWRlMWIK"
  }
}
print(vim.inspect(vim.fn.json_decode(res.body)))
