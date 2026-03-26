print('(premium-script) custom name title by Nperma')

onPlayerEnterWorldCallback(function(world, player)
  local item = getItem(1446)
  player:sendVariant({
    "OnNameChanged",
    player:getName(),
    string.format(
      "{\"PlayerWorldID\":%d,\"TitleTexture\":\"game/%s\",\"TitleTextureCoordinates\":\"%d,%d\",\"WrenchCustomization\":{\"WrenchForegroundCanRotate\":false,\"WrenchForegroundID\":-1,\"WrenchIconID\":-1}}",
      player:getNetID(), item:getTexture(), item:getTextureX(), item:getTextureY())
  }, 0, player:getNetID())
end)