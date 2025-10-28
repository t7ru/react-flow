local React = require(script.Parent.Parent.React)

local createElement = React.createElement
local useState = React.useState
local useEffect = React.useEffect
local memo = React.memo
local cloneElement = React.cloneElement
local useMemo = React.useMemo

-- Shallow identity signature
local function makeChildrenSig(children)
	local sig = {}
	for k, v in children do
		sig[#sig+1] = tostring(k) .. ":" .. tostring(v)
	end
	table.sort(sig)
	return table.concat(sig, "|")
end

-- DynamicList reconciles a dictionary of keyed children.
-- Fixes: previous code wrapped ALL children with removal props each render causing churn & potential loops.
-- Strategy: only wrap children flagged for removal; avoid mutating props; bail out when no change.
local function DynamicList(props: { children: {} })
	local children = props.children
	local list, setList = useState({})

	-- Rerun only when keys/child shallow identities change
	local sig = useMemo(function()
		return makeChildrenSig(children)
	end, { children })

	useEffect(function()
		setList(function(prevState)
			local nextState = table.clone(prevState)
			local changed = false

			-- Add or update active children
			for key, child in children do
				if nextState[key] ~= child then
					nextState[key] = child
					changed = true
				end
			end

			-- Wrap removals once and cleanup
			for key, existing in prevState do
				if children[key] == nil and existing ~= nil then
					local alreadyRemoving = existing.props and existing.props.remove
					if not alreadyRemoving then
						local function destroy()
							setList(function(currentState)
								if currentState[key] == nil then return currentState end
								local c = table.clone(currentState)
								c[key] = nil
								return c
							end)
						end
						nextState[key] = cloneElement(existing, { remove = true, destroy = destroy })
						changed = true
					end
				end
			end

			return changed and nextState or prevState
		end)
	end, { sig })

	return createElement(React.Fragment, nil, list)
end

return memo(DynamicList)