function choose_cell_renderings()
  function jsonDecodeArray(json)
    if json:sub(1, 1) == '[' then
      return quarto.json.decode(json)
    elseif json:sub(1, 1) == '{' then
      quarto.log.warning('expected array or scalar', json)
    else
      return {json}
    end
  end

  local documentRenderings
  
  return {
    traverse = "topdown",
    Meta = function(meta)
      if meta.renderings then
        documentRenderings = {}
        for _, inlines in ipairs(meta.renderings) do
          table.insert(documentRenderings, inlines[1].text)
        end
      end
    end,
    Div = function(div)
      -- Only process cell div with renderings attr
      if not div.classes:includes("cell") or (not documentRenderings and not div.attributes["renderings"]) then
        return nil
      end
      local renderings
      if div.attributes['renderings'] then
        local renderingsJson = div.attributes['renderings']
        renderings = jsonDecodeArray(renderingsJson)
      else
        renderings = documentRenderings
      end
      if not type(renderings) == "table" or #renderings == 0 then
        quarto.log.warning("renderings expected array of rendering names, got", renderings)
        return nil
      end
      local cods = {}
      local firstCODIndex = nil
      for i, cellOutput in ipairs(div.content) do
        if cellOutput.classes:includes("cell-output-display") then
          if not firstCODIndex then
            firstCODIndex = i
          end
          table.insert(cods, cellOutput)
        end
      end
    
      if #cods ~= #renderings then
        quarto.log.warning("need", #renderings, "cell-output-display for renderings", table.concat(renderings, ",") .. ";", "got", #cods)
        return nil
      end
    
      local outputs = {}
      for i, r in ipairs(renderings) do
        outputs[r] = cods[i]
      end
      local lightDiv = outputs['light']
      local darkDiv = outputs['dark']
      local blocks = pandoc.Blocks({table.unpack(div.content, 1, firstCODIndex - 1)})
      if quarto.format.isHtmlOutput() and lightDiv and darkDiv then
        blocks:insert(pandoc.Div(lightDiv.content, pandoc.Attr("", {'light-content'}, {})))
        blocks:insert(pandoc.Div(darkDiv.content, pandoc.Attr("", {'dark-content'}, {})))
      elseif quarto.format.isTypstOutput() and lightDiv and darkDiv then
        local brandMode = param('brand-mode') or 'light'
        if brandMode == 'light' then
          blocks:insert(lightDiv)
        elseif brandMode == 'dark' then
          blocks:insert(darkDiv)
        end
      else
        blocks:insert(lightDiv or darkDiv)
      end
      div.content = blocks
      return div
    end
  }
end