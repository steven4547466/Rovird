local HttpService = game:GetService("HttpService")
local Selection = game:GetService("Selection")
local CollectionService = game:GetService("CollectionService")

local toolbar = plugin:CreateToolbar("Rovird")
local openUiButton = toolbar:CreateButton("Rovird Plugin GUI", "Flags scripts that could possibly contain or require viruses", "rbxassetid://4458901886")

openUiButton.ClickableWhenViewportHidden = true

local baseUrl = "https://rovird.xyz/jobs"

local lastJobs = {}
local lastUUIDs = {}

local previousResults = {}

local ui = nil

local doNotCheckTag = "Rovird_DoNotCheck"

local info = {
	InternalScanned=0;
	ExternalScanned=0;
	TotalScanned=0;
	TotalFlags=0;
}

function trim(s)
	return s:gsub("^%s+", ""):gsub("%s+$", "")
end

function UpdateInfo(prop, newValue)
	local label = ui.Frame.Results.Folder.OverallInfo:FindFirstChild(prop)
	if label then 
		label.Text = trim(label.Text:gsub("%d", ""))
		label.Text = label.Text .. " " .. tostring(newValue)
	end
	info[prop] = newValue
end

function openUi()
	if ui ~= nil then
		ui.Enabled = true
	else
		ui = plugin:CreateDockWidgetPluginGui(
			"Rovird",
			DockWidgetPluginGuiInfo.new(
				Enum.InitialDockState.Float,
				true,
				true,
				588,
				310,
				588,
				310
			)
		)
		ui.Title = "Rovird Advanced Virus Detector"
		local frame = script.Frame
		frame.Size = UDim2.new(1,0,1,0)
		frame.Parent = ui
		frame.Main.ToggleDNC.MouseButton1Click:Connect(toggleDNC)
		frame.Main.SendJob.MouseButton1Click:Connect(sendJob)
		frame.Main.Results.MouseButton1Click:Connect(getResults)
		frame.Main.ListDNC.MouseButton1Click:Connect(listDNC)
	end
end

function listDNC()
	for i, v in ipairs(CollectionService:GetTagged(doNotCheckTag)) do
		local button = script.Parent.Button:Clone()
		button.Name = "ListItem"
		button.Text = v.Name
		button.Parent = ui.Frame.DNCList
		button.MouseButton1Click:Connect(function()
			Selection:Set({v})
			if v:IsA("LuaSourceContainer") then
				plugin:OpenScript(v)
			end
		end)
		button.MouseButton2Click:Connect(function()
			CollectionService:RemoveTag(v, doNotCheckTag)
			button:Destroy()
		end)
	end
	ui.Frame.Main.Visible = false
	ui.Frame.DNCList.Visible = true
end

function toggleDNC()
	local selection = Selection:Get()
	for i, v in ipairs(selection) do
		if CollectionService:HasTag(v, doNotCheckTag) then
			CollectionService:RemoveTag(v, doNotCheckTag)
		else
			CollectionService:AddTag(v, doNotCheckTag)
		end
	end
end

function sendJob()
	for k in pairs(info) do
		UpdateInfo(k, 0)
	end
	table.clear(lastJobs)
	table.clear(lastJobs)
	table.clear(previousResults)
	local toPost = {}
	topLevel(game, toPost, 1, nil)
	local chunked = {}
	for i, v in ipairs(toPost) do
		table.insert(chunked, chunk(v, 10))
	end
	
	local large = {}
	
	for i = 1, #chunked do
		local v = chunked[i]
		for j = 1, #v do
			local v2 = v[j]
			for k = 1, #v2 do
				if v2[k] == nil then break end
				if isLarge(v2[k]) then
					print("Large found, will be skipped")
					table.insert(large, v2[k])
					table.remove(v2, k)
					k -= 1
				end
			end
		end
	end
	
	for _, v in ipairs(chunked) do
		for _, v2 in ipairs(v) do
			table.insert(lastJobs, HttpService:JSONDecode(HttpService:PostAsync(baseUrl, HttpService:JSONEncode(v2))).jobId)
			if #v2 > 60 then task.wait(1) end
		end
	end
end

function getResults()
	local toRemove = {}
	if #lastJobs > 0 then
		for i, jobId in ipairs(lastJobs) do
			local res = HttpService:RequestAsync({["Url"]=baseUrl.."?jobId="..jobId;["Method"]="GET"})
			if res.StatusCode ~= 200 then
				print("Job Id " .. jobId .. " returned non-200 code: " .. tostring(res.StatusCode))
				print("Message from server:")
				print(res.Body)
				if res.Body ~= "Job not yet complete. Try again soon" then
					table.insert(toRemove, jobId)
				end
				continue
			end
			table.insert(toRemove, jobId)
			local results = HttpService:JSONDecode(res.Body)
			executeResults(results)
			table.insert(previousResults, results)
		end
	else
		for i, results in ipairs(previousResults) do
			executeResults(results)
		end
	end
	
	for i, v in ipairs(toRemove) do
		local index = table.find(lastJobs, v)
		if index ~= nil then table.remove(lastJobs, index) end
	end
	
	ui.Frame.Main.Visible = false
	ui.Frame.Results.Visible = true
end

function executeResults(results)
	local toClone = script.Parent.Button
	for i, result in ipairs(results) do
		for uuid, r in pairs(result) do
			local name = ""
			if lastUUIDs[uuid] == nil then
				name = r.name
			else
				name = lastUUIDs[uuid].Name
			end
			local button = toClone:Clone()
			button.Name = "ListItem"
			button.Text = name .. " (" .. getLocationInWorkspace(lastUUIDs[uuid], r) .. ")"
			button.TextScaled = false
			button.TextWrapped = true
			button.TextSize = 22
			button.UIAspectRatioConstraint.AspectRatio = 4
			button.Parent = ui.Frame.Results
			UpdateInfo("TotalFlags", info.TotalFlags + #r.flags)
			UpdateInfo("TotalScanned", info.TotalScanned + 1)
			if r.isExternal > 0 then
				UpdateInfo("ExternalScanned", info.ExternalScanned + 1)
			else
				UpdateInfo("InternalScanned", info.InternalScanned + 1)
			end
			if #r.flags > 0 then
				button.BackgroundColor3 = Color3.new(1,0,0)
				button:SetAttribute("HasFlags", true)
			else
				button.BackgroundColor3 = Color3.new(0,1,0)
				button:SetAttribute("HasFlags", false)
			end
			button.MouseButton2Click:Connect(function()
				if r.isExternal == 0 then
					plugin:OpenScript(lastUUIDs[uuid])
				else
					print("Can't open external script. You may view it here: https://www.roblox.com/library/" .. tostring(r.assetId))
				end
			end)
			button.MouseButton1Click:Connect(function()
				for i, v in ipairs(ui.Frame.Results:GetChildren()) do
					if v.Name == "ListItem" then
						v:Destroy()
					end
				end

				local titleButton = toClone:Clone()
				titleButton.Name = "ListItem"
				titleButton.Text = name .. " (" .. getLocationInWorkspace(lastUUIDs[uuid], r) .. ")"
				titleButton.TextScaled = false
				titleButton.TextWrapped = true
				titleButton.TextSize = 22
				titleButton.UIAspectRatioConstraint.AspectRatio = 4
				titleButton.Parent = ui.Frame.Info
				titleButton.MouseButton1Click:Connect(function()
					if r.isExternal == 0 then
						plugin:OpenScript(lastUUIDs[uuid])
					else
						print("Can't open external script. You may view it here: https://www.roblox.com/library/" .. tostring(r.assetId))
					end
				end)

				for i, f in ipairs(r.flags) do
					local flagButton = toClone:Clone()
					flagButton.Name = "ListItem"
					flagButton.Text = f.reason
					flagButton.TextScaled = false
					flagButton.TextWrapped = true
					flagButton.TextSize = 22
					flagButton.UIAspectRatioConstraint.AspectRatio = 4
					flagButton.Parent = ui.Frame.Info
					flagButton.BackgroundColor3 = Color3.new(1,0,0)
					flagButton.MouseButton1Click:Connect(function()
						if r.isExternal == 0 then
							plugin:OpenScript(lastUUIDs[uuid], f.line)
						else
							print("Can't open external script. You may view it here: https://www.roblox.com/library/" .. tostring(r.assetId) .. " line number: " .. tostring(f.line))
						end
					end)
				end

				ui.Frame.Results.Visible = false
				ui.Frame.Info.Visible = true
				-- Get more info
			end)
		end
	end
end

function backwardsParent(m, parents)
	table.insert(parents, m.Name)
	if m.Parent ~= game then
		backwardsParent(m.Parent, parents)
	end
end

function getLocationInWorkspace(m, result)
	local parents = {}
	if m == nil then
		return "External " .. result.isExternal
	else
		backwardsParent(m, parents)
	end
	local hierarchy = ""	
	for i = #parents, 1, -1 do
		hierarchy = hierarchy..parents[i]
		if i ~= 1 then
			hierarchy = hierarchy.."."
		end
	end
	return hierarchy
end

function isLarge(data)
	local encoded = HttpService:JSONEncode(data)
	if string.len(encoded) > 1024000 then
		return true
	end 
	return false
end

function getChunk(arr, startIndex, endIndex)
	local chunk = {}
	for i = startIndex, endIndex do
		if arr[i] then
			table.insert(chunk, arr[i])
		else
			break
		end
	end
	return chunk
end

function chunk(arr, chunkSize)
	local chunked = {}
	for i = 1, #arr, chunkSize do
		table.insert(chunked, getChunk(arr, i, i+chunkSize - 1))
	end
	return chunked
end

function topLevel(parent, toPost, curIndex, parentScript)
	if parentScript == nil then
		table.insert(toPost, {})
		curIndex = #toPost
	end
	for _, dataModel in ipairs(parent:GetChildren()) do
		pcall(function()
			for _, child in ipairs(dataModel:GetChildren()) do
				if child:IsA("LuaSourceContainer") and not child:IsA("CoreScript") then
					if CollectionService:HasTag(child, doNotCheckTag) then continue end
					local schema = {["Source"]=child.Source, ["Children"]={}, ["UUID"]=HttpService:GenerateGUID(false)}
					lastUUIDs[schema.UUID] = child
					table.insert(toPost[curIndex], schema)
					recurseChildren(child, schema)
				else
					local schema = {}
					table.insert(toPost[curIndex], schema)
					recurseChildren(child, schema)
					if schema.Source == nil then table.remove(toPost[curIndex], #toPost[curIndex]) end
				end
			end
		end)
	end
end

function recurseChildren(parent, schema)
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("LuaSourceContainer") and not child:IsA("CoreScript") then
			if CollectionService:HasTag(child, doNotCheckTag) then continue end
			if schema.Source == nil then
				schema.Source = child.Source
				schema.Children = {}
				schema.UUID = HttpService:GenerateGUID(false)
				lastUUIDs[schema.UUID] = child
				recurseChildren(child, schema)
			else
				local childSchema = {["Source"]=child.Source, ["Children"]={}, ["UUID"]=HttpService:GenerateGUID(false)}
				lastUUIDs[childSchema.UUID] = child
				table.insert(schema.Children, childSchema)
				recurseChildren(child, childSchema)
			end
		else
			recurseChildren(child, schema)
		end
	end
end

openUiButton.Click:Connect(openUi)