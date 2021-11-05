script.Parent.Parent.CanvasSize = UDim2.new(1,0,0,script.Parent.AbsoluteContentSize.Y)
script.Parent:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	script.Parent.Parent.CanvasSize = UDim2.new(1,0,0,script.Parent.AbsoluteContentSize.Y) 
end)