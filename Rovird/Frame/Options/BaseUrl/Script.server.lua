function endsWith(str, ending)
	return ending == "" or str:sub(-#ending) == ending
end

script.Parent.FocusLost:Connect(function(enterPressed, inputThatCausedFocusLost)
	if enterPressed then
		if not endsWith(script.Parent.Text, "/") then
			script.Parent.Text ..= "/"
		end
		plugin:SetSetting("baseUrl", script.Parent.Text)
	end
end)