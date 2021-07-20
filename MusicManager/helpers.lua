local Helpers = MusicManager.Helpers or
{ }

function Helpers:GetCaseInsensTableKey(tbl, strToFind)
  for key in pairs(tbl) do
    local keyStr = tostring(key)

    if keyStr:lower() == strToFind:lower() then
      return keyStr
    end
  end

  return nil
end

function Helpers:PrintToChat(pid, msg, isErr, toAll, beforeMsg)
  local colour = isErr and color.Red or color.GreenText
  beforeMsg = beforeMsg and true or ""

  tes3mp.SendMessage(pid, string.format("%s%s[MusicManager]: %s\n", beforeMsg, colour, msg), toAll)
end

return Helpers