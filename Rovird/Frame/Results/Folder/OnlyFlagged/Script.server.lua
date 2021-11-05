script.Parent.MouseButton1Click:Connect(function()
	for i, v in ipairs(script.Parent.Parent.Parent:GetChildren()) do
		if v.Name == "ListItem" then
			if not v:GetAttribute("HasFlags") then
				v.Visible = not v.Visible
			end
		end
	end
end)