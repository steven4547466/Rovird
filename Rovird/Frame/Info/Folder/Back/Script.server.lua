script.Parent.MouseButton1Click:Connect(function()
	for i, v in ipairs(script.Parent.Parent.Parent:GetChildren()) do
		if v.Name == "ListItem" then
			v:Destroy()
		end
	end
	script.Parent.Parent.Parent.Visible = false
	script.Parent.Parent.Parent.Parent.Main.Visible = true
end)