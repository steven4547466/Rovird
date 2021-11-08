local HttpService = game:GetService("HttpService")
local Selection = game:GetService("Selection")
local CollectionService = game:GetService("CollectionService")

local toolbar = plugin:CreateToolbar("Rovird")
local openUiButton = toolbar:CreateButton("Rovird Plugin GUI", "Flags scripts that could possibly contain or require viruses", "rbxassetid://4458901886")

openUiButton.ClickableWhenViewportHidden = true

local hasRunBefore = plugin:GetSetting("hasRunBefore")
if not hasRunBefore then
	plugin:SetSetting("hasRunBefore", true)
	plugin:SetSetting("baseUrl", "https://rovird.xyz/")
end

local lastJobs = {}
local lastUUIDs = {}

local previousResults = {}

local ui = nil

local doNotCheckTag = "Rovird_DoNotCheck"

local resultsLocked = false

local info = {
	InternalScanned=0;
	ExternalScanned=0;
	TotalScanned=0;
	TotalFlags=0;
}

function getBaseUrl()
	return plugin:GetSetting("baseUrl")
end

function getUrl(ext)
	return getBaseUrl()..ext
end

function trim(s)
	return s:gsub("^%s+", ""):gsub("%s+$", "")
end

function updateInfo(prop, newValue)
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
		frame.Main.Options.MouseButton1Click:Connect(openOptions)
	end
end

function openOptions()
	ui.Frame.Options.BaseUrl.Text = getBaseUrl()
	ui.Frame.Main.Visible = false
	ui.Frame.Options.Visible = true
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
		updateInfo(k, 0)
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
	
	ui.Frame.Main.Results.BackgroundColor3 = Color3.new(0.329412, 0.329412, 0.329412)
	resultsLocked = true
	
	for _, v in ipairs(chunked) do
		if down then break end
		for _, v2 in ipairs(v) do
			if #v2 == 0 then continue end
			local success, res = pcall(HttpService.RequestAsync, HttpService, {["Url"]=getUrl("jobs");["Method"]="POST";["Body"]=HttpService:JSONEncode(v2),["Headers"]={["Content-Type"]="application/json"}})
			if not success then
				ui.Frame.Main.Results.BackgroundColor3 = Color3.new(1,0,0)
				error("Connection to " .. getBaseUrl() .. " was refused.")
			end
			if res.StatusCode ~= 200 then
				print("Posting job returned non-200 code: " .. tostring(res.StatusCode))
				if res.StatusCode ~= 413 then
					print("Message from server:")
					print(res.Body)
				end
				continue
			end
			table.insert(lastJobs, HttpService:JSONDecode(res.Body).jobId)
			if #v2 > 60 then task.wait(1) end
		end
	end
	while true do
		local res = HttpService:RequestAsync({["Url"]=getUrl("jobs-status").."?jobIds="..table.concat(lastJobs,",");["Method"]="GET"})
		if res.StatusCode ~= 200 then
			ui.Frame.Main.Results.BackgroundColor3 = Color3.new(1,0,0)
			print("Failed to get job status")
			print("Message from server:")
			print(res.Body)
			break
		else
			local flag = false
			
			for id, value in pairs(HttpService:JSONDecode(res.Body)) do
				if value == 0 then
					flag = true
					break
				end
			end
			
			if not flag then
				resultsLocked = false
				ui.Frame.Main.Results.BackgroundColor3 = Color3.new(0, 1, 0)
				break
			end
		end
		
		task.wait(0.5)
	end
end

function getResults()
	if resultsLocked then return end
	for k in pairs(info) do
		updateInfo(k, 0)
	end
	local toRemove = {}
	if #lastJobs > 0 then
		for i, jobId in ipairs(lastJobs) do
			local res = HttpService:RequestAsync({["Url"]=getUrl("jobs").."?jobId="..jobId;["Method"]="GET"})
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
			updateInfo("TotalFlags", info.TotalFlags + #r.flags)
			updateInfo("TotalScanned", info.TotalScanned + 1)
			if r.isExternal > 0 then
				updateInfo("ExternalScanned", info.ExternalScanned + 1)
			else
				updateInfo("InternalScanned", info.InternalScanned + 1)
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
	if m.Parent == nil then
		table.insert(parents, "(Deleted)")
		return
	end
	if m.Parent ~= game then
		backwardsParent(m.Parent, parents)
	end
end

function getLocationInWorkspace(m, result)
	local parents = {}
	if m == nil then
		return "External " .. result.isExternal
	elseif m.Parent == nil then
		return "Deleted"
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
			if dataModel.Name == "CoreGui" then return end
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