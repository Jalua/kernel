-- Lifted from MoonScript@GitHub
try = (t) ->
  ok,err = pcall t.do
  unless ok
      t.catch err
  t.finally! if t.finally

return try
