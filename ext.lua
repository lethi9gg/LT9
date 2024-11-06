(function()
	local modules = {};
	modules["ext.os"] = function()
		local os = {};
		for k, v in pairs(require("os")) do
			os[k] = v;
		end
		local io = require("ext.io");
		local table = require("ext.table");
		local string = require("ext.string");
		local assert = require("ext.assert");
		local detect_lfs = require("ext.detect_lfs");
		local detect_os = require("ext.detect_os");
		os.sep = (detect_os() and "\\") or "/";
		function os.path(str)
			assert.type(str, "string");
			return (str:gsub("/", os.sep));
		end
		if _VERSION == "Lua 5.1" then
			local execute = os.execute;
			function os.execute(cmd)
				local results = table.pack(execute(cmd));
				if #results > 1 then
					return results:unpack();
				end
				local errcode = results[1];
				local reason = ({[0]="exit"})[errcode] or "unknown";
				return ((errcode == 0) and true) or nil, reason, errcode;
			end
		end
		function os.exec(cmd)
			print(">" .. cmd);
			return os.execute(cmd);
		end
		function os.mkdir(dir, makeParents)
			local tonull;
			if detect_os() then
				dir = os.path(dir);
				tonull = " 2> nul";
				makeParents = nil;
			else
				tonull = " 2> /dev/null";
			end
			local cmd = "mkdir" .. ((makeParents and " -p") or "") .. " " .. ("%q"):format(dir) .. tonull;
			return os.execute(cmd);
		end
		function os.rmdir(dir)
			local cmd = 'rmdir "' .. os.path(dir) .. '"';
			return os.execute(cmd);
		end
		function os.move(from, to)
			from = os.path(from);
			to = os.path(to);
			local cmd = ((detect_os() and "move") or "mv") .. ' "' .. from .. '" "' .. to .. '"';
			return os.execute(cmd);
		end
		function os.isdir(fn)
			local lfs = detect_lfs();
			if lfs then
				local attr = lfs.attributes(fn);
				if not attr then
					return false;
				end
				return attr.mode == "directory";
			elseif detect_os() then
				return "yes" == string.trim(io.readproc('if exist "' .. os.path(fn) .. '\\*" (echo yes) else (echo no)'));
			else
				local f = io.open(fn, "rb");
				if not f then
					return false;
				end
				local result, reason, errcode = f:read(1);
				f:close();
				if (result == nil) and (reason == "Is a directory") and (errcode == 21) then
					return true;
				end
				return false;
			end
		end
		function os.listdir(path)
			local lfs = detect_lfs();
			if not lfs then
				local fns;
				local cmd;
				if detect_os() then
					cmd = 'dir /b "' .. os.path(path) .. '"';
				else
					cmd = "ls -a " .. path:gsub("[|&;<>`\"' \t\r\n#~=%$%(%)%%%[%*%?]", "\\%0");
				end
				local filestr = io.readproc(cmd);
				fns = string.split(filestr, "\n");
				assert.eq(fns:remove(), "");
				if fns[1] == "." then
					fns:remove(1);
				end
				if fns[1] == ".." then
					fns:remove(1);
				end
				return coroutine.wrap(function()
					for _, k in ipairs(fns) do
						coroutine.yield(k);
					end
				end);
			else
				return coroutine.wrap(function()
					for k in lfs.dir(path) do
						if (k ~= ".") and (k ~= "..") then
							coroutine.yield(k);
						end
					end
				end);
			end
		end
		function os.rlistdir(dir, callback)
			return coroutine.wrap(function()
				for f in os.listdir(dir) do
					local path = dir .. "/" .. f;
					if os.isdir(path) then
						if (not callback) or callback(path, true) then
							for f in os.rlistdir(path, callback) do
								coroutine.yield(f);
							end
						end
					elseif (not callback) or callback(path, false) then
						local fn = path;
						if (#fn > 2) and (fn:sub(1, 2) == "./") then
							fn = fn:sub(3);
						end
						coroutine.yield(fn);
					end
				end
			end);
		end
		function os.fileexists(fn)
			assert(fn, "expected filename");
			local lfs = detect_lfs();
			if lfs then
				return lfs.attributes(fn) ~= nil;
			elseif detect_os() then
				return "yes" == string.trim(io.readproc('if exist "' .. os.path(fn) .. '" (echo yes) else (echo no)'));
			else
				local f, err = io.open(fn, "r");
				if not f then
					return false, err;
				end
				f:close();
				return true;
			end
		end
		function os.home()
			local home = os.getenv("HOME") or os.getenv("USERPROFILE");
			if not home then
				return false, "failed to find environment variable HOME or USERPROFILE";
			end
			return home;
		end
		return os;
	end;
	modules["ext.op"] = function()
		local load = loadstring or load;
		local lua53 = _VERSION >= "Lua 5.3";
		local symbolscode = "\n\t-- which fields are unary operators\n\tlocal unary = {\n\t\tunm = true,\n\t\tbnot = true,\n\t\tlen = true,\n\t\tlnot = true,\n\t}\n\n\tlocal symbols = {\n\t\tadd = '+',\n\t\tsub = '-',\n\t\tmul = '*',\n\t\tdiv = '/',\n\t\tmod = '%',\n\t\tpow = '^',\n\t\tunm = '-',\t\t\t-- unary\n\t\tconcat = '..',\n\t\teq = '==',\n\t\tne = '~=',\n\t\tlt = '<',\n\t\tle = '<=',\n\t\tgt = '>',\n\t\tge = '>=',\n\t\tland = 'and',\t\t-- non-overloadable\n\t\tlor = 'or',\t\t\t-- non-overloadable\n\t\tlen = '#',\t\t\t-- unary\n\t\tlnot = 'not',\t\t-- non-overloadable, unary\n";
		if lua53 then
			symbolscode = symbolscode .. "\t\tidiv = '//',\t\t-- 5.3\n\t\tband = '&',\t\t\t-- 5.3\n\t\tbor = '|',\t\t\t-- 5.3\n\t\tbxor = '~',\t\t\t-- 5.3\n\t\tshl = '<<',\t\t\t-- 5.3\n\t\tshr = '>>',\t\t\t-- 5.3\n\t\tbnot = '~',\t\t\t-- 5.3, unary\n";
		end
		symbolscode = symbolscode .. "\t}\n";
		local symbols, unary = assert(load(symbolscode .. " return symbols, unary"))();
		local code = symbolscode .. "\t-- functions for operators\n\tlocal ops\n\tops = {\n";
		for name, symbol in pairs(symbols) do
			if unary[name] then
				code = code .. "\t\t" .. name .. " = function(a) return " .. symbol .. " a end,\n";
			else
				code = code .. "\t\t" .. name .. " = function(a,b) return a " .. symbol .. " b end,\n";
			end
		end
		code = code .. "\t\tindex = function(t, k) return t[k] end,\n\t\tnewindex = function(t, k, v)\n\t\t\tt[k] = v\n\t\t\treturn t, k, v\t-- ? should it return anything ?\n\t\tend,\n\t\tcall = function(f, ...) return f(...) end,\n\n\t\tsymbols = symbols,\n\n\t\t-- special pcall wrapping index, thanks luajit.  thanks.\n\t\t-- while i'm here, multiple indexing, so it bails out nil early, so it's a chained .? operator\n\t\tsafeindex = function(t, ...)\n\t\t\tif select('#', ...) == 0 then return t end\n\t\t\tlocal res, v = pcall(ops.index, t, ...)\n\t\t\tif not res then return nil, v end\n\t\t\treturn ops.safeindex(v, select(2, ...))\n\t\tend,\n\t}\n\treturn ops\n";
		return assert(load(code))();
	end;
	modules["ext.cmdline"] = function()
		local fromlua = require("ext.fromlua");
		local assert = require("ext.assert");
		local table = require("ext.table");
		local string = require("ext.string");
		local tolua = require("ext.tolua");
		function getCmdline(...)
			local cmdline = {...};
			for _, w in ipairs({...}) do
				local k, v = w:match("^(.-)=(.*)$");
				if k then
					pcall(function()
						cmdline[k] = fromlua(v);
					end);
					if cmdline[k] == nil then
						cmdline[k] = v;
					end
				else
					cmdline[w] = true;
				end
			end
			return cmdline;
		end
		function showHelp(cmdValue, cmdKey, cmdline, desc)
			print("specify commands via `command` or `command=value`");
			print();
			print("commands:");
			for _, k in ipairs(table.keys(desc):sort()) do
				local descValue = desc[k];
				if descValue.desc then
					print("\t" .. descValue.name .. " = " .. string.trim(descValue.desc):gsub("\n", "\n\t\t"));
				else
					print("\t" .. descValue.name);
				end
				print();
			end
		end
		function showHelpAndQuit(...)
			showHelp(...);
			os.exit(0);
		end
		function validate(desc)
			for _, name in ipairs(table.keys(desc)) do
				local descValue = desc[name];
				if descValue == true then
					descValue = {};
				elseif type(descValue) == "string" then
					descValue = {type=descValue};
				elseif type(descValue) == "function" then
					descValue = {validate=descValue};
				elseif type(descValue) == "table" then
				else
					error("idk how to handle this cmdline description " .. tolua(descValue));
				end
				if (not descValue.type) and (not descValue.validate) then
					function descValue.validate()
					end
				end
				if descValue.type then
					assert(not descValue.validate, "you should provide either a .type or a .validate, but not both");
					local descType = descValue.type;
					function descValue.validate(cmdValue, key, cmdline)
						if descType == "number" then
							cmdline[name] = assert(tonumber(cmdValue));
						elseif descType == "file" then
							assert.type(cmdValue, "string");
							assert(require("ext.path")(cmdValue):exists(), "failed to find file " .. tolua(cmdValue));
						else
							assert.type(cmdValue, descType);
						end
					end
				end
				descValue.name = name;
				desc[name] = descValue;
			end
			local cmdlineValidation = {};
			function cmdlineValidation:fromTable(cmdline)
				for _, k in ipairs(table.keys(cmdline)) do
					local cmdValue = cmdline[k];
					if type(k) == "number" then
					elseif type(k) == "string" then
						local descValue = desc[k];
						if not descValue then
							error("got an unknown command " .. tolua(k));
						else
							descValue.validate(cmdValue, k, cmdline, desc);
						end
					else
						error("got a cmdline with an unknown key type: " .. tolua(k));
					end
				end
				for k, v in pairs(desc) do
					if v.must then
						if not cmdline[k] then
							error("expected to find key " .. k);
						end
					end
				end
				return cmdline;
			end
			setmetatable(cmdlineValidation, {__call=function(self, ...)
				return self:fromTable(getCmdline(...));
			end});
			return cmdlineValidation;
		end
		return setmetatable({getCmdline=getCmdline, validate=validate, showHelp=showHelp, showHelpAndQuit=showHelpAndQuit}, {__call=function(t, ...)
			return getCmdline(...);
		end});
	end;
	modules["ext.detect_lfs"] = function()
		local lfs;
		function detect_lfs()
			if lfs == nil then
				for _, try in ipairs({"lfs", "lfs_ffi"}) do
					local result;
					result, lfs = pcall(require, try);
					lfs = result and lfs;
					if lfs then
						break;
					end
				end
			end
			return lfs;
		end
		return detect_lfs;
	end;
	modules["ext.tolua"] = function()
		local table = require("ext.table");
		function builtinPairs(t)
			return next, t, nil;
		end
		local _0byte = ("0"):byte();
		local _9byte = ("9"):byte();
		function escapeString(s)
			local o = ("%q"):format(s);
			o = o:gsub("\\\n", "\\n");
			return o;
		end
		local reserved = {["and"]=true, ["break"]=true, ["do"]=true, ["else"]=true, ["elseif"]=true, ["end"]=true, ["false"]=true, ["for"]=true, ["function"]=true, ["goto"]=true, ["if"]=true, ["in"]=true, ["local"]=true, ["nil"]=true, ["not"]=true, ["or"]=true, ["repeat"]=true, ["return"]=true, ["then"]=true, ["true"]=true, ["until"]=true, ["while"]=true};
		function isVarName(k)
			return (type(k) == "string") and k:match("^[_a-zA-Z][_a-zA-Z0-9]*$") and (not reserved[k]);
		end
		local toLuaRecurse;
		function toLuaKey(state, k, path)
			if isVarName(k) then
				return k, true;
			else
				local result = toLuaRecurse(state, k, nil, path, true);
				if result then
					return "[" .. result .. "]", false;
				else
					return false, false;
				end
			end
		end
		function maxn(t, state)
			local max = 0;
			local count = 0;
			for k, v in state.pairs(t) do
				count = count + 1;
				if type(k) == "number" then
					max = math.max(max, k);
				end
			end
			return max, count;
		end
		local defaultSerializeForType = {number=function(state, x)
			if x == math.huge then
				return "math.huge";
			end
			if x == -math.huge then
				return "-math.huge";
			end
			if x ~= x then
				return "0/0";
			end
			return tostring(x);
		end, boolean=function(state, x)
			return tostring(x);
		end, ["nil"]=function(state, x)
			return tostring(x);
		end, string=function(state, x)
			return escapeString(x);
		end, ["function"]=function(state, x)
			local result, s = pcall(string.dump, x);
			if result then
				s = "load(" .. escapeString(s) .. ")";
			elseif s == "unable to dump given function" then
				local found;
				for k, v in state.pairs(_G) do
					if v == x then
						found = true;
						s = k;
						break;
					elseif type(v) == "table" then
						for k2, v2 in state.pairs(v) do
							if v2 == x then
								s = k .. "." .. k2;
								found = true;
								break;
							end
						end
						if found then
							break;
						end
					end
				end
				if not found then
					s = "error('" .. s .. "')";
				end
			else
				return "error('got a function I could neither dump nor lookup in the global namespace nor one level deep')";
			end
			return s;
		end, table=function(state, x, tab, path, keyRef)
			local result;
			local newtab = tab .. state.indentChar;
			if state.touchedTables[x] then
				if state.skipRecursiveReferences then
					result = 'error("recursive reference")';
				else
					result = false;
					state.wrapWithFunction = true;
					if keyRef then
						state.recursiveReferences:insert("root" .. path .. "[" .. state.touchedTables[x] .. '] = error("can\'t handle recursive references in keys")');
					else
						state.recursiveReferences:insert("root" .. path .. " = " .. state.touchedTables[x]);
					end
				end
			else
				state.touchedTables[x] = "root" .. path;
				local numx, count = maxn(x, state);
				local intNilKeys, intNonNilKeys;
				if numx < (2 * count) then
					intNilKeys, intNonNilKeys = 0, 0;
					for i = 1, numx do
						if x[i] == nil then
							intNilKeys = intNilKeys + 1;
						else
							intNonNilKeys = intNonNilKeys + 1;
						end
					end
				end
				local hasSubTable;
				local s = table();
				local addedIntKeys = {};
				if intNonNilKeys and intNilKeys and (intNonNilKeys >= (intNilKeys * 2)) then
					for k = 1, numx do
						if type(x[k]) == "table" then
							hasSubTable = true;
						end
						local nextResult = toLuaRecurse(state, x[k], newtab, path and (path .. "[" .. k .. "]"));
						if nextResult then
							s:insert(nextResult);
						end
						addedIntKeys[k] = true;
					end
				end
				local mixed = table();
				for k, v in state.pairs(x) do
					if not addedIntKeys[k] then
						if type(v) == "table" then
							hasSubTable = true;
						end
						local keyStr, usesDot = toLuaKey(state, k, path);
						if keyStr then
							local newpath;
							if path then
								newpath = path;
								if usesDot then
									newpath = newpath .. ".";
								end
								newpath = newpath .. keyStr;
							end
							local nextResult = toLuaRecurse(state, v, newtab, newpath);
							if nextResult then
								mixed:insert({keyStr, nextResult});
							end
						end
					end
				end
				mixed:sort(function(a, b)
					return a[1] < b[1];
				end);
				mixed = mixed:map(function(kv)
					return table.concat(kv, "=");
				end);
				s:append(mixed);
				local thisNewLineChar, thisNewLineSepChar, thisTab, thisNewTab;
				if (not hasSubTable) and (not state.alwaysIndent) then
					thisNewLineChar = "";
					thisNewLineSepChar = " ";
					thisTab = "";
					thisNewTab = "";
				else
					thisNewLineChar = state.newlineChar;
					thisNewLineSepChar = state.newlineChar;
					thisTab = tab;
					thisNewTab = newtab;
				end
				local rs = "{" .. thisNewLineChar;
				if #s > 0 then
					rs = rs .. thisNewTab .. s:concat("," .. thisNewLineSepChar .. thisNewTab) .. thisNewLineChar;
				end
				rs = rs .. thisTab .. "}";
				result = rs;
			end
			return result;
		end};
		function defaultSerializeMetatableFunc(state, m, x, tab, path, keyRef)
			if type(x) ~= "table" then
				return "nil";
			end
			return toLuaRecurse(state, m, tab .. state.indentChar, path, keyRef);
		end
		function toLuaRecurse(state, x, tab, path, keyRef)
			if not tab then
				tab = "";
			end
			local xtype = type(x);
			local serializeFunction;
			if state.serializeForType then
				serializeFunction = state.serializeForType[xtype];
			end
			if not serializeFunction then
				serializeFunction = defaultSerializeForType[xtype];
			end
			local result;
			if serializeFunction then
				result = serializeFunction(state, x, tab, path, keyRef);
			else
				result = "[" .. type(x) .. ":" .. tostring(x) .. "]";
			end
			assert(result ~= nil);
			if state.serializeMetatables then
				local m = getmetatable(x);
				if m ~= nil then
					local serializeMetatableFunc = state.serializeMetatableFunc or defaultSerializeMetatableFunc;
					local mstr = serializeMetatableFunc(state, m, x, tab, path, keyRef);
					assert(mstr ~= nil);
					if (mstr ~= "nil") and (mstr ~= false) then
						assert(result ~= false);
						result = "setmetatable(" .. result .. ", " .. mstr .. ")";
					end
				end
			end
			return result;
		end
		function tolua(x, args)
			local state = {indentChar="", newlineChar="", wrapWithFunction=false, recursiveReferences=table(), touchedTables={}};
			local indent = true;
			if args then
				if args.indent == false then
					indent = false;
				end
				if args.indent == "always" then
					state.alwaysIndent = true;
				end
				state.serializeForType = args.serializeForType;
				state.serializeMetatables = args.serializeMetatables;
				state.serializeMetatableFunc = args.serializeMetatableFunc;
				state.skipRecursiveReferences = args.skipRecursiveReferences;
			end
			if indent then
				state.indentChar = "\t";
				state.newlineChar = "\n";
			end
			state.pairs = builtinPairs;
			local str = toLuaRecurse(state, x, nil, "");
			if state.wrapWithFunction then
				str = "(function()" .. state.newlineChar .. state.indentChar .. "local root = " .. str .. " " .. state.newlineChar .. state.recursiveReferences:concat(" " .. state.newlineChar .. state.indentChar) .. " " .. state.newlineChar .. state.indentChar .. "return root " .. state.newlineChar .. "end)()";
			end
			return str;
		end
		return setmetatable({}, {__call=function(self, x, args)
			return tolua(x, args);
		end, __index={escapeString=escapeString, isVarName=isVarName, defaultSerializeForType=defaultSerializeForType, defaultSerializeMetatableFunc=defaultSerializeMetatableFunc}});
	end;
	modules["ext.fromlua"] = function()
		return function(str, ...)
			return assert(load("return " .. str, ...))();
		end;
	end;
	modules["ext.meta"] = function()
		local assert = require("ext.assert");
		local table = require("ext.table");
		local string = require("ext.string");
		local number = require("ext.number");
		local op = require("ext.op");
		debug.setmetatable(nil, {__concat=string.concat});
		debug.setmetatable(true, {__concat=string.concat, __index={and_=op.land, or_=op.lor, not_=op.lnot, xor=function(a, b)
			return a ~= b;
		end, implies=function(a, b)
			return (not a) or b;
		end}});
		debug.setmetatable(0, number);
		getmetatable("").__concat = string.concat;
		getmetatable("").__index = string;
		function combineFunctionsWithBinaryOperator(f, g, opfunc)
			if (type(f) == "function") and (type(g) == "function") then
				return function(...)
					return opfunc(f(...), g(...));
				end;
			elseif type(f) == "function" then
				return function(...)
					return opfunc(f(...), g);
				end;
			elseif type(g) == "function" then
				return function(...)
					return opfunc(f, g(...));
				end;
			else
				return function()
					return opfunc(f, g);
				end;
			end
		end
		local functionMeta = {__concat=string.concat, dump=function(f)
			return string.dump(f);
		end, __add=function(f, g)
			return combineFunctionsWithBinaryOperator(f, g, op.add);
		end, __sub=function(f, g)
			return combineFunctionsWithBinaryOperator(f, g, op.sub);
		end, __mul=function(f, g)
			return combineFunctionsWithBinaryOperator(f, g, op.mul);
		end, __div=function(f, g)
			return combineFunctionsWithBinaryOperator(f, g, op.div);
		end, __mod=function(f, g)
			return combineFunctionsWithBinaryOperator(f, g, op.mod);
		end, __pow=function(f, g)
			return combineFunctionsWithBinaryOperator(f, g, op.pow);
		end, __unm=function(f)
			return function(...)
				return -f(...);
			end;
		end, __len=function(f)
			return function(...)
				return #f(...);
			end;
		end, __index={index=function(f, k)
			return function(...)
				return f(...)[k];
			end;
		end, assign=function(f, k, v)
			return function(...)
				f(...)[k] = v;
			end;
		end, compose=function(...)
			local funcs = table.pack(...);
			for i = 1, funcs.n do
				assert.type(funcs[i], "function");
			end
			return function(...)
				local args = table.pack(...);
				for i = funcs.n, 1, -1 do
					args = table.pack(funcs[i](table.unpack(args, 1, args.n)));
				end
				return table.unpack(args, 1, args.n);
			end;
		end, compose_n=function(f, n, ...)
			local funcs = table.pack(...);
			return function(...)
				local args = table.pack(...);
				local ntharg = {args[n]};
				ntharg.n = ((n <= args.n) and 1) or 0;
				for i = funcs.n, 1, -1 do
					ntharg = table.pack(funcs[i](table.unpack(ntharg, 1, ntharg.n)));
				end
				args[n] = ntharg[1];
				args.n = math.max(args.n, n);
				return f(table.unpack(args, 1, args.n));
			end;
		end, bind=function(f, ...)
			local args = table.pack(...);
			return function(...)
				local n = args.n;
				local callargs = {table.unpack(args, 1, n)};
				for i = 1, select("#", ...) do
					n = n + 1;
					callargs[n] = select(i, ...);
				end
				return f(table.unpack(callargs, 1, n));
			end;
		end, bind_n=function(f, n, ...)
			local nargs = table.pack(...);
			return function(...)
				local args = table.pack(...);
				for i = 1, nargs.n do
					args[(n + i) - 1] = nargs[i];
				end
				args.n = math.max(args.n, (n + nargs.n) - 1);
				return f(table.unpack(args, 1, args.n));
			end;
		end, uncurry=function(f, n)
			return function(...)
				local s = f;
				for i = 1, n do
					s = s(select(i, ...));
				end
				return s;
			end;
		end, nargs=function(f, n)
			return function(...)
				local t = {};
				for i = 1, n do
					t[i] = select(i, ...);
				end
				return f(table.unpack(t, 1, n));
			end;
		end, swap=function(f)
			return function(a, b, ...)
				return f(b, a, ...);
			end;
		end, dump=string.dump}};
		functionMeta.__index._ = functionMeta.__index.index;
		functionMeta.__index.o = functionMeta.__index.compose;
		functionMeta.__index.o_n = functionMeta.__index.compose_n;
		debug.setmetatable(function()
		end, functionMeta);
	end;
	modules["ext.string"] = function()
		local string = {};
		for k, v in pairs(require("string")) do
			string[k] = v;
		end
		local table = require("ext.table");
		function string.split(s, exp)
			exp = exp or "";
			s = tostring(s);
			local t = table();
			if exp == "" then
				for i = 1, #s do
					t:insert(s:sub(i, i));
				end
			else
				local searchpos = 1;
				local start, fin = s:find(exp, searchpos);
				while start do
					t:insert(s:sub(searchpos, start - 1));
					searchpos = fin + 1;
					start, fin = s:find(exp, searchpos);
				end
				t:insert(s:sub(searchpos));
			end
			return t;
		end
		function string.trim(s)
			return s:match("^%s*(.-)%s*$");
		end
		function string.bytes(s)
			return table({s:byte(1, #s)});
		end
		string.load = load or loadstring;
		function string.csub(d, start, size)
			if not size then
				return string.sub(d, start + 1);
			end
			return string.sub(d, start + 1, start + size);
		end
		function string.hexdump(d, l, w, c)
			d = tostring(d);
			l = tonumber(l);
			w = tonumber(w);
			c = tonumber(c);
			if (not l) or (l < 1) then
				l = 32;
			end
			if (not w) or (w < 1) then
				w = 1;
			end
			if (not c) or (c < 1) then
				c = 8;
			end
			local s = table();
			local rhs = table();
			local col = 0;
			for i = 1, #d, w do
				if (i % l) == 1 then
					s:insert(string.format("%.8x ", i - 1));
					rhs = table();
					col = 1;
				end
				s:insert(" ");
				for j = w, 1, -1 do
					local e = (i + j) - 1;
					local sub = d:sub(e, e);
					if #sub > 0 then
						local b = string.byte(sub);
						s:insert(string.format("%.2x", b));
						rhs:insert(((b >= 32) and sub) or ".");
					end
				end
				if (col % c) == 0 then
					s:insert(" ");
				end
				if ((((i + w) - 1) % l) == 0) or ((i + w) > #d) then
					s:insert(" ");
					s:insert(rhs:concat());
				end
				if (((i + w) - 1) % l) == 0 then
					s:insert("\n");
				end
				col = col + 1;
			end
			return s:concat();
		end
		local escapeFind = "[" .. ("^$()%.[]*+-?"):gsub(".", "%%%1") .. "]";
		function string.patescape(s)
			return (s:gsub(escapeFind, "%%%1"));
		end
		function string.concat(...)
			local n = select("#", ...);
			if n == 0 then
				return;
			end
			local s = tostring((...));
			if n == 1 then
				return s;
			end
			return s .. string.concat(select(2, ...));
		end
		function string:nametostring()
			local mt = getmetatable(self);
			setmetatable(self, nil);
			local s = tostring(self);
			setmetatable(self, mt);
			local name = mt.__name;
			return (name and (tostring(name) .. s:sub(6))) or s;
		end
		return string;
	end;
	modules["ext.class"] = function()
		local table = require("ext.table");
		function newmember(class, ...)
			local obj = setmetatable({}, class);
			if obj.init then
				return obj, obj:init(...);
			end
			return obj;
		end
		local classmeta = {__call=function(self, ...)
			return self:new(...);
		end};
		function isa(cl, obj)
			assert(cl, "isa: argument 1 is nil, should be the class object");
			if type(obj) ~= "table" then
				return false;
			end
			if not obj.isaSet then
				return false;
			end
			return obj.isaSet[cl] or false;
		end
		function class(...)
			local cl = table(...);
			cl.class = cl;
			cl.super = ...;
			cl.isaSet = {[cl]=true};
			for i = 1, select("#", ...) do
				local parent = select(i, ...);
				if parent ~= nil then
					cl.isaSet[parent] = true;
					if parent.isaSet then
						for grandparent, _ in pairs(parent.isaSet) do
							cl.isaSet[grandparent] = true;
						end
					end
				end
			end
			for ancestor, _ in pairs(cl.isaSet) do
				ancestor.descendantSet = ancestor.descendantSet or {};
				ancestor.descendantSet[cl] = true;
			end
			cl.__index = cl;
			cl.new = newmember;
			cl.isa = isa;
			cl.subclass = class;
			setmetatable(cl, classmeta);
			return cl;
		end
		return class;
	end;
	modules["ext.math"] = function()
		local math = {};
		for k, v in pairs(require("math")) do
			math[k] = v;
		end
		math.nan = (0/0);
		math.e = math.exp(1);
		if not math.atan2 then
			math.atan2 = math.atan;
		end
		if not math.sinh then
			function math.sinh(x)
				local ex = math.exp(x);
				return 0.5 * (ex - (1 / ex));
			end
		end
		if not math.cosh then
			function math.cosh(x)
				local ex = math.exp(x);
				return 0.5 * (ex + (1 / ex));
			end
		end
		if not math.tanh then
			function math.tanh(x)
				if x < 0 then
					local e2x = math.exp(2 * x);
					return (e2x - 1) / (e2x + 1);
				else
					local em2x = math.exp(-2 * x);
					return (1 - em2x) / (1 + em2x);
				end
			end
		end
		function math.asinh(x)
			return math.log(x + math.sqrt((x * x) + 1));
		end
		function math.acosh(x)
			return math.log(x + math.sqrt((x * x) - 1));
		end
		function math.atanh(x)
			return 0.5 * math.log((1 + x) / (1 - x));
		end
		function math.cbrt(x)
			return math.sign(x) * (math.abs(x) ^ (1 / 3));
		end
		function math.clamp(v, min, max)
			return math.max(math.min(v, max), min);
		end
		function math.sign(x)
			if x < 0 then
				return -1;
			end
			if x > 0 then
				return 1;
			end
			return 0;
		end
		function math.trunc(x)
			if x < 0 then
				return math.ceil(x);
			else
				return math.floor(x);
			end
		end
		function math.round(x)
			return math.floor(x + 0.5);
		end
		function math.isnan(x)
			return x ~= x;
		end
		function math.isinf(x)
			return (x == math.huge) or (x == -math.huge);
		end
		function math.isfinite(x)
			return tonumber(x) and (not math.isnan(x)) and (not math.isinf(x));
		end
		function math.isprime(n)
			if n < 2 then
				return false;
			end
			for i = 2, math.floor(math.sqrt(n)) do
				if (n % i) == 0 then
					return false;
				end
			end
			return true;
		end
		function math.factorial(n)
			local prod = 1;
			for i = 1, n do
				prod = prod * i;
			end
			return prod;
		end
		function math.factors(n)
			local table = require("ext.table");
			local f = table();
			for i = 1, n do
				if (n % i) == 0 then
					f:insert(i);
				end
			end
			return f;
		end
		function math.primeFactorization(n)
			local table = require("ext.table");
			n = math.floor(n);
			local f = table();
			while n > 1 do
				local found = false;
				for i = 2, math.floor(math.sqrt(n)) do
					if (n % i) == 0 then
						n = math.floor(n / i);
						f:insert(i);
						found = true;
						break;
					end
				end
				if not found then
					f:insert(n);
					break;
				end
			end
			return f;
		end
		function math.gcd(a, b)
			return ((b == 0) and a) or math.gcd(b, a % b);
		end
		function math.mix(a, b, s)
			return (a * (1 - s)) + (b * s);
		end
		return math;
	end;
	modules["ext.number"] = function()
		local math = require("ext.math");
		local hasutf8, utf8 = pcall(require, "utf8");
		local number = {};
		number.__index = number;
		for k, v in pairs(math) do
			number[k] = math[k];
		end
		number.alphabets = {{("0"):byte(), ("9"):byte()}, {("a"):byte(), ("z"):byte()}, {945, 969}, {1072, 1119}, {1377, 1414}, {2309, 2361}, {12032, 12245}, {12353, 12438}, {12449, 12538}, {19968, 40912}};
		function number.charfor(digit)
			local table = require("ext.table");
			for _, alphabet in ipairs(number.alphabets) do
				local start, fin = table.unpack(alphabet);
				if digit <= (fin - start) then
					digit = digit + start;
					if hasutf8 then
						return utf8.char(digit);
					else
						return string.char(digit);
					end
				end
				digit = digit - ((fin - start) + 1);
			end
			error("you need more alphabets to represent that many digits");
		end
		function number.todigit(ch)
			local table = require("ext.table");
			local indexInAlphabet;
			if hasutf8 then
				indexInAlphabet = utf8.codepoint(ch);
			else
				indexInAlphabet = string.byte(ch);
			end
			local lastTotalIndex = 0;
			for _, alphabet in ipairs(number.alphabets) do
				local start, fin = table.unpack(alphabet);
				if (indexInAlphabet >= start) and (indexInAlphabet <= fin) then
					return lastTotalIndex + (indexInAlphabet - start);
				end
				lastTotalIndex = lastTotalIndex + (fin - start) + 1;
			end
			error("couldn't find the character in all the alphabets");
		end
		number.base = 10;
		number.maxdigits = 50;
		function number.tostring(t, base, maxdigits)
			local s = {};
			if t < 0 then
				t = -t;
				table.insert(s, "-");
			end
			if t == 0 then
				table.insert(s, "0.");
			else
				if not base then
					base = number.base;
				end
				if not maxdigits then
					maxdigits = number.maxdigits;
				end
				local i = math.floor(math.log(t, base)) + 1;
				if i == math.huge then
					error("infinite number of digits");
				end
				t = t / (base ^ i);
				local dot;
				while true do
					if i < 1 then
						if not dot then
							dot = true;
							table.insert(s, ".");
							table.insert(s, ("0"):rep(-i));
						end
						if t == 0 then
							break;
						end
						if i <= -maxdigits then
							break;
						end
					end
					t = t * base;
					local digit = math.floor(t);
					t = t - digit;
					table.insert(s, number.charfor(digit));
					i = i - 1;
				end
			end
			return table.concat(s);
		end
		number.char = string.char;
		return number;
	end;
	modules["ext.io"] = function()
		local io = {};
		for k, v in pairs(require("io")) do
			io[k] = v;
		end
		function io.readfile(fn)
			local f, err = io.open(fn, "rb");
			if not f then
				return false, err;
			end
			local d = f:read("*a");
			f:close();
			return d;
		end
		function io.writefile(fn, d)
			local f, err = io.open(fn, "wb");
			if not f then
				return false, err;
			end
			if d then
				f:write(d);
			end
			f:close();
			return true;
		end
		function io.appendfile(fn, d)
			local f, err = io.open(fn, "ab");
			if not f then
				return false, err;
			end
			if d then
				f:write(d);
			end
			f:close();
			return true;
		end
		function io.readproc(cmd)
			local f, err = io.popen(cmd);
			if not f then
				return false, err;
			end
			local d = f:read("*a");
			f:close();
			return d;
		end
		function io.getfiledir(fn)
			local dir, name = fn:match("^(.*)/([^/]-)$");
			if not dir then
				return ".", fn;
			end
			return dir, name;
		end
		function io.getfileext(fn)
			local front, ext = fn:match("^(.*)%.([^%./]-)$");
			if front then
				return front, ext;
			end
			return fn, nil;
		end
		do
			local detect_lfs = require("ext.detect_lfs");
			local lfs = detect_lfs();
			if lfs then
				local filemeta = debug.getmetatable(io.stdout);
				filemeta.lock = lfs.lock;
				filemeta.unlock = lfs.unlock;
			end
		end
		return io;
	end;
	modules["ext.detect_ffi"] = function()
		local ffi;
		function detect_ffi()
			if ffi == nil then
				local result;
				result, ffi = pcall(require, "ffi");
				ffi = result and ffi;
			end
			return ffi;
		end
		return detect_ffi;
	end;
	modules["ext.load"] = function()
		local stateForEnv = {};
		return function(env)
			env = env or _G;
			local state = stateForEnv[env];
			if state then
				return state;
			end
			state = {};
			require("ext.xpcall")(env);
			local package = env.package or _G.package;
			local searchpath = package.searchpath;
			if not searchpath then
				function searchpath(name, path, sep, rep)
					sep = sep or ";";
					rep = rep or "/";
					local namerep = name:gsub("%.", rep);
					local attempted = {};
					for w in path:gmatch("[^" .. sep .. "]*") do
						local fn = w;
						if fn == "" then
						else
							fn = fn:gsub("%?", namerep);
							local exists = io.open(fn, "rb");
							if exists then
								exists:close();
								return fn;
							end
							table.insert(attempted, "\n\tno file '" .. fn .. "'");
						end
					end
					return nil, table.concat(attempted);
				end
			end
			state.xforms = setmetatable({}, {__index=table});
			local loadUsesFunctions = (_VERSION == "Lua 5.1") and (not env.jit);
			state.oldload = (loadUsesFunctions and (env.loadstring or _G.loadstring)) or env.load or _G.load;
			function state.load(data, ...)
				if type(data) == "function" then
					local s = {};
					repeat
						local chunk = data();
						if (chunk == "") or (chunk == nil) then
							break;
						end
						table.insert(s, chunk);
					until false
					data = table.concat(s);
				end
				local source = ... or ("[" .. data:sub(1, 10) .. "...]");
				for i, xform in ipairs(state.xforms) do
					local reason;
					data, reason = xform(data, source);
					if not data then
						return false, "ext.load.xform[" .. i .. "]: " .. ((reason and tostring(reason)) or "");
					end
				end
				return state.oldload(data, ...);
			end
			if (env.loadstring ~= nil) or (_G.loadstring ~= nil) then
				state.oldloadstring = env.loadstring or _G.loadstring;
				state.loadstring = state.load;
				env.loadstring = state.loadstring;
			end
			env.load = state.load;
			state.oldloadfile = env.loadfile or _G.loadfile;
			function state.loadfile(...)
				local filename = ...;
				local data, err;
				if filename then
					local f;
					f, err = io.open(filename, "rb");
					if not f then
						return nil, err;
					end
					data, err = f:read("*a");
					f:close();
				else
					data, err = io.read("*a");
				end
				if err then
					return nil, err;
				end
				if data then
					data = data:match("^#[^\n]*\n(.*)$") or data;
				end
				return state.load(data, ...);
			end
			env.loadfile = state.loadfile;
			state.olddofile = env.dofile or _G.dofile;
			function state.dofile(filename)
				return assert(state.loadfile(filename))();
			end
			env.dofile = state.dofile;
			local searchers = assert(package.searchers or package.loaders, "couldn't find searchers");
			state.oldsearchfile = searchers[2];
			function state.searchfile(req, ...)
				local filename, err = searchpath(req, package.path);
				if not filename then
					return err;
				end
				local f, err = state.loadfile(filename);
				return f or err;
			end
			searchers[2] = state.searchfile;
			stateForEnv[env] = state;
			return state;
		end;
	end;
	modules["ext.timer"] = function()
		local hasffi, ffi = pcall(require, "ffi");
		local T = {};
		T.out = io.stderr;
		T.getTime = os.clock;
		T.depth = 0;
		T.tab = " ";
		function timerReturn(name, startTime, indent, ...)
			local endTime = T.getTime();
			local dt = endTime - startTime;
			T.depth = T.depth - 1;
			T.out:write(indent .. "...done ");
			if name then
				T.out:write(name .. " ");
			end
			T.out:write("(" .. dt .. "s)\n");
			T.out:flush();
			return dt, ...;
		end
		function T.timer(name, cb, ...)
			local indent = T.tab:rep(T.depth);
			if name then
				T.out:write(indent .. name .. "...\n");
			end
			T.out:flush();
			local startTime = T.getTime();
			T.depth = T.depth + 1;
			return timerReturn(name, startTime, indent, cb(...));
		end
		function timerReturnQuiet(startTime, ...)
			local endTime = T.getTime();
			local dt = endTime - startTime;
			return dt, ...;
		end
		function T.timerQuiet(cb, ...)
			local startTime = T.getTime();
			return timerReturnQuiet(startTime, cb(...));
		end
		setmetatable(T, {__call=function(self, ...)
			return self.timer(...);
		end});
		return T;
	end;
	modules["ext.assert"] = function()
		function tostr(x)
			if type(x) == "string" then
				return ("%q"):format(x);
			end
			return tostring(x);
		end
		function prependmsg(msg, str)
			if type(msg) == "number" then
				msg = tostring(msg);
			end
			if type(msg) == "nil" then
				return str;
			end
			if type(msg) == "string" then
				return msg .. ": " .. str;
			end
			return msg;
		end
		function asserttype(x, t, msg, ...)
			local xt = type(x);
			if xt ~= t then
				error(prependmsg(msg, "expected " .. tostring(t) .. " found " .. tostring(xt)));
			end
			return x, t, msg, ...;
		end
		function assertis(obj, cl, msg, ...)
			if not cl.isa then
				error(prependmsg(msg, "assertis expected 2nd arg to be a class"));
			end
			if not cl:isa(obj) then
				error(prependmsg(msg, "object " .. tostring(obj) .. " is not of class " .. tostring(cl)));
			end
			return obj, cl, msg, ...;
		end
		function asserttypes(msg, n, ...)
			asserttype(n, "number", prependmsg(msg, "asserttypes number of args"));
			for i = 1, n do
				asserttype(select(n + i, ...), select(i, ...), prependmsg(msg, "asserttypes arg " .. i));
			end
			return select(n + 1, ...);
		end
		function asserteq(a, b, msg, ...)
			if not (a == b) then
				error(prependmsg(msg, "got " .. tostr(a) .. " == " .. tostr(b)));
			end
			return a, b, msg, ...;
		end
		function asserteqeps(a, b, eps, msg, ...)
			eps = eps or 1.0E-7;
			if math.abs(a - b) > eps then
				error(((msg and (msg .. ": ")) or "") .. "expected |" .. a .. " - " .. b .. "| < " .. eps);
			end
			return a, b, eps, msg, ...;
		end
		function assertne(a, b, msg, ...)
			if not (a ~= b) then
				error(prependmsg(msg, "got " .. tostr(a) .. " ~= " .. tostr(b)));
			end
			return a, b, msg, ...;
		end
		function assertlt(a, b, msg, ...)
			if not (a < b) then
				error(prependmsg(msg, "got " .. tostr(a) .. " < " .. tostr(b)));
			end
			return a, b, msg, ...;
		end
		function assertle(a, b, msg, ...)
			if not (a <= b) then
				error(prependmsg(msg, "got " .. tostr(a) .. " <= " .. tostr(b)));
			end
			return a, b, msg, ...;
		end
		function assertgt(a, b, msg, ...)
			if not (a > b) then
				error(prependmsg(msg, "got " .. tostr(a) .. " > " .. tostr(b)));
			end
			return a, b, msg, ...;
		end
		function assertge(a, b, msg, ...)
			if not (a >= b) then
				error(prependmsg(msg, "got " .. tostr(a) .. " >= " .. tostr(b)));
			end
			return a, b, msg, ...;
		end
		function assertindex(t, k, msg, ...)
			if not t then
				error(prependmsg(msg, "object is nil"));
			end
			local v = t[k];
			assert(v, prependmsg(msg, "expected " .. tostr(t) .. "[" .. tostr(k) .. " ]"));
			return v, msg, ...;
		end
		function asserttableieq(t1, t2, msg, ...)
			asserteq(#t1, #t2, msg);
			for i = 1, #t1 do
				asserteq(t1[i], t2[i], msg);
			end
			return t1, t2, msg, ...;
		end
		function assertlen(t, n, msg, ...)
			asserteq(#t, n, msg);
			return t, n, msg, ...;
		end
		function asserterror(f, msg, ...)
			asserteq(pcall(f, ...), false, msg);
			return f, msg, ...;
		end
		local origassert = _G.assert;
		return setmetatable({type=asserttype, types=asserttypes, is=assertis, eq=asserteq, ne=assertne, lt=assertlt, le=assertle, gt=assertgt, ge=assertge, index=assertindex, eqeps=asserteqeps, tableieq=asserttableieq, len=assertlen, error=asserterror}, {__call=function(t, ...)
			return origassert(...);
		end});
	end;
	function modules.ext()
		require("ext.meta");
		require("ext.env")();
	end
	modules["ext.detect_os"] = function()
		local detect_ffi = require("ext.detect_ffi");
		local result;
		function detect_os()
			if result ~= nil then
				return result;
			end
			local ffi = detect_ffi();
			if ffi then
				result = ffi.os == "Windows";
			else
				result = false;
			end
			return result;
		end
		return detect_os;
	end;
	modules["ext.table"] = function()
		local table = {};
		for k, v in pairs(require("table")) do
			table[k] = v;
		end
		table.__index = table;
		function table.new(...)
			return setmetatable({}, table):union(...);
		end
		setmetatable(table, {__call=function(t, ...)
			return table.new(...);
		end});
		table.unpack = table.unpack or unpack;
		local origTableUnpack = table.unpack;
		function table.unpack(...)
			local nargs = select("#", ...);
			local t, i, j = ...;
			if (nargs < 3) and (t.n ~= nil) then
				return origTableUnpack(t, i or 1, t.n);
			end
			return origTableUnpack(...);
		end
		if not table.pack then
			function table.pack(...)
				local t = {...};
				t.n = select("#", ...);
				return setmetatable(t, table);
			end
		else
			local oldpack = table.pack;
			function table.pack(...)
				return setmetatable(oldpack(...), table);
			end
		end
		if not table.maxn then
			function table.maxn(t)
				local max = 0;
				for k, v in pairs(t) do
					if type(k) == "number" then
						max = math.max(max, k);
					end
				end
				return max;
			end
		end
		function table:union(...)
			for i = 1, select("#", ...) do
				local o = select(i, ...);
				if o then
					for k, v in pairs(o) do
						self[k] = v;
					end
				end
			end
			return self;
		end
		function table:append(...)
			for i = 1, select("#", ...) do
				local u = select(i, ...);
				if u then
					for _, v in ipairs(u) do
						table.insert(self, v);
					end
				end
			end
			return self;
		end
		function table:removeKeys(...)
			for i = 1, select("#", ...) do
				local v = select(i, ...);
				self[v] = nil;
			end
		end
		function table:map(cb)
			local t = table();
			for k, v in pairs(self) do
				local nv, nk = cb(v, k, t);
				if nk == nil then
					nk = k;
				end
				t[nk] = nv;
			end
			return t;
		end
		function table:mapi(cb)
			local t = table();
			for k = 1, #self do
				local v = self[k];
				local nv, nk = cb(v, k, t);
				if nk == nil then
					nk = k;
				end
				t[nk] = nv;
			end
			return t;
		end
		function table:filter(f)
			local t = table();
			if type(f) == "function" then
				for k, v in pairs(self) do
					if f(v, k) then
						if type(k) == "string" then
							t[k] = v;
						else
							t:insert(v);
						end
					end
				end
			else
				error("table.filter second arg must be a function");
			end
			return t;
		end
		function table:keys()
			local t = table();
			for k, _ in pairs(self) do
				t:insert(k);
			end
			return t;
		end
		function table:values()
			local t = table();
			for _, v in pairs(self) do
				t:insert(v);
			end
			return t;
		end
		function table:find(value, eq)
			if eq then
				for k, v in pairs(self) do
					if eq(v, value) then
						return k, v;
					end
				end
			else
				for k, v in pairs(self) do
					if v == value then
						return k, v;
					end
				end
			end
		end
		function table:insertUnique(value, eq)
			if not table.find(self, value, eq) then
				table.insert(self, value);
			end
		end
		function table:removeObject(...)
			local removedKeys = table();
			local len = #self;
			local k = table.find(self, ...);
			while k ~= nil do
				if (type(k) == "number") and (tonumber(k) <= len) then
					table.remove(self, k);
				else
					self[k] = nil;
				end
				removedKeys:insert(k);
				k = table.find(self, ...);
			end
			return table.unpack(removedKeys);
		end
		function table:kvpairs()
			local t = table();
			for k, v in pairs(self) do
				table.insert(t, {[k]=v});
			end
			return t;
		end
		function table:sup(cmp)
			local bestk, bestv;
			if cmp then
				for k, v in pairs(self) do
					if (bestv == nil) or cmp(v, bestv) then
						bestk, bestv = k, v;
					end
				end
			else
				for k, v in pairs(self) do
					if (bestv == nil) or (v > bestv) then
						bestk, bestv = k, v;
					end
				end
			end
			return bestv, bestk;
		end
		function table:inf(cmp)
			local bestk, bestv;
			if cmp then
				for k, v in pairs(self) do
					if (bestv == nil) or cmp(v, bestv) then
						bestk, bestv = k, v;
					end
				end
			else
				for k, v in pairs(self) do
					if (bestv == nil) or (v < bestv) then
						bestk, bestv = k, v;
					end
				end
			end
			return bestv, bestk;
		end
		function table:combine(callback)
			local s;
			for _, v in pairs(self) do
				if s == nil then
					s = v;
				else
					s = callback(s, v);
				end
			end
			return s;
		end
		local op = require("ext.op");
		function table:sum()
			return table.combine(self, op.add);
		end
		function table:product()
			return table.combine(self, op.mul);
		end
		function table:last()
			return self[#self];
		end
		function table.sub(t, i, j)
			if i < 0 then
				i = math.max(1, #t + i + 1);
			end
			j = j or #t;
			j = math.min(j, #t);
			if j < 0 then
				j = math.min(#t, #t + j + 1);
			end
			local res = {};
			for k = i, j do
				res[(k - i) + 1] = t[k];
			end
			setmetatable(res, table);
			return res;
		end
		function table.reverse(t)
			local r = table();
			for i = #t, 1, -1 do
				r:insert(t[i]);
			end
			return r;
		end
		function table.rep(t, n)
			local c = table();
			for i = 1, n do
				c:append(t);
			end
			return c;
		end
		local oldsort = require("table").sort;
		function table:sort(...)
			oldsort(self, ...);
			return self;
		end
		function table.shuffle(t)
			t = table(t);
			for i = #t, 2, -1 do
				local j = math.random(i - 1);
				t[i], t[j] = t[j], t[i];
			end
			return t;
		end
		function table.pickRandom(t)
			return t[math.random(#t)];
		end
		function table.wrapfor(f, s, var)
			local t = table();
			while true do
				local vars = table.pack(f(s, var));
				local var_1 = vars[1];
				if var_1 == nil then
					break;
				end
				var = var_1;
				t:insert(vars);
			end
			return t;
		end
		function permgen(t, n)
			if n < 1 then
				coroutine.yield(t);
			else
				for i = n, 1, -1 do
					t[n], t[i] = t[i], t[n];
					permgen(t, n - 1);
					t[n], t[i] = t[i], t[n];
				end
			end
		end
		function table.permutations(t)
			return coroutine.wrap(function()
				permgen(t, table.maxn(t));
			end);
		end
		table.setmetatable = setmetatable;
		return table;
	end;
	modules["ext.env"] = function()
		require("ext.gc");
		local table = require("ext.table");
		return function(env)
			env = env or _G;
			require("ext.xpcall")(env);
			require("ext.load")(env);
			env.math = require("ext.math");
			env.table = table;
			env.string = require("ext.string");
			env.io = require("ext.io");
			env.os = require("ext.os");
			env.path = require("ext.path");
			env.tolua = require("ext.tolua");
			env.fromlua = require("ext.fromlua");
			env.class = require("ext.class");
			env.reload = require("ext.reload");
			env.range = require("ext.range");
			env.timer = require("ext.timer");
			env.op = require("ext.op");
			env.getCmdline = require("ext.cmdline");
			--env.cmdline = env.getCmdline(table.unpack(arg or {}));
			env._ = os.execute;
			env.assert = require("ext.assert");
			for k, v in pairs(env.assert) do
				env["assert" .. k] = v;
			end
		end;
	end;
	modules["ext.reload"] = function()
		function reload(n)
			package.loaded[n] = nil;
			return require(n);
		end
		return reload;
	end;
	modules["ext.range"] = function()
		local table = require("ext.table");
		function range(a, b, c)
			local t = table();
			if c then
				for x = a, b, c do
					t:insert(x);
				end
			elseif b then
				for x = a, b do
					t:insert(x);
				end
			else
				for x = 1, a do
					t:insert(x);
				end
			end
			return t;
		end
		return range;
	end;
	modules["ext.path"] = function()
		local detect_os = require("ext.detect_os");
		local detect_lfs = require("ext.detect_lfs");
		local assert = require("ext.assert");
		local io = require("ext.io");
		local os = require("ext.os");
		local string = require("ext.string");
		local class = require("ext.class");
		function simplifypath(p)
			p = string.split(p, "/");
			for i = #p - 1, 1, -1 do
				if i > 1 then
					while p[i] == "" do
						p:remove(i);
					end
				end
				while p[i] == "." do
					p:remove(i);
				end
				if (p[i + 1] == "..") and (p[i] ~= "..") then
					if (i == 1) and (p[1] == "") then
						error("/.. absolute + previous doesn't make sense");
					end
					p:remove(i);
					p:remove(i);
				end
			end
			while (#p > 1) and (p[#p] == ".") do
				p:remove();
			end
			return p:concat("/");
		end
		function appendPath(...)
			local fn, p = assert.types("appendPath", 2, "string", "string", ...);
			if fn:sub(1, 1) ~= "/" then
				fn = p .. "/" .. fn;
			end
			fn = fn:gsub("/%./", "/");
			fn = fn:gsub("/+", "/");
			if (#fn > 2) and (fn:sub(1, 2) == "./") then
				fn = fn:sub(3);
			end
			return fn;
		end
		local Path = class();
		function Path:init(args)
			self.path = assert.type(assert.type(args, "table", "Path:init args").path, "string", "Path:init args.path");
			assert.ne(self.path, nil);
		end
		local mappings = {[io]={lines="lines", open="open", read="readfile", write="writefile", append="appendfile"}, [os]={remove="remove", mkdir="mkdir", rmdir="rmdir", exists="fileexists", isdir="isdir", fixpathsep="path"}};
		local lfs = detect_lfs();
		if lfs then
			mappings[lfs] = {attr="attributes", symattr="symlinkattributes", cd="chdir", link="link", setmode="setmode", touch="touch", lockdir="lock_dir"};
		end
		for obj, mapping in pairs(mappings) do
			for k, v in pairs(mapping) do
				Path[k] = function(self, ...)
					return obj[v](self.path, ...);
				end;
			end
		end
		function Path:getdir(...)
			local dir, name = io.getfiledir(self.path, ...);
			return Path({path=dir}), Path({path=name});
		end
		function Path:getext(...)
			local base, ext = io.getfileext(self.path);
			return Path({path=base}), ext;
		end
		function Path:cwd()
			if lfs then
				return Path({path=lfs.currentdir()});
			elseif detect_os() then
				return Path({path=string.trim(io.readproc("cd"))});
			else
				return Path({path=string.trim(io.readproc("pwd"))});
			end
		end
		function Path:abs()
			if self.path:sub(1, 1) == "/" then
				return self;
			end
			return Path:cwd() / self;
		end
		function Path:move(to)
			if Path:isa(to) then
				to = to.path;
			end
			return os.move(self.path, to);
		end
		function Path:dir()
			if not os.isdir(self.path) then
				error("can't dir() a non-directory");
			end
			return coroutine.wrap(function()
				for fn in os.listdir(self.path) do
					coroutine.yield(Path({path=fn}));
				end
			end);
		end
		function Path:rdir(callback)
			if not os.isdir(self.path) then
				error("can't rdir() a non-directory");
			end
			return coroutine.wrap(function()
				for fn in os.rlistdir(self.path, callback) do
					coroutine.yield(Path({path=fn}));
				end
			end);
		end
		function Path:setext(newext)
			local base = self:getext().path;
			if newext then
				base = base .. "." .. newext;
			end
			return Path({path=base});
		end
		function Path:__call(k)
			assert.ne(self.path, nil);
			if k == nil then
				return self;
			end
			if Path:isa(k) then
				k = k.path;
			end
			local fn = assert.type(appendPath(k, self.path), "string", "Path:__call appendPath(k, self.path)");
			fn = simplifypath(fn);
			return Path({path=assert.type(fn, "string", "Path:__call simplifypath")});
		end
		Path.__div = Path.__call;
		function Path:__tostring()
			return self:fixpathsep();
		end
		function Path:escape()
			return ("%q"):format(self:fixpathsep());
		end
		Path.__concat = string.concat;
		local pathSys = Path({path="."});
		return pathSys;
	end;
	modules["ext.xpcall"] = function()
		return function(env)
			env = env or _G;
			local oldxpcall = env.xpcall or _G.xpcall;
			local xpcallfwdargs = select(2, oldxpcall(function(x)
				return x;
			end, function()
			end, true));
			if xpcallfwdargs then
				return;
			end
			local unpack = env.unpack or table.unpack;
			function newxpcall(f, err, ...)
				local args = {...};
				args.n = select("#", ...);
				return oldxpcall(function()
					return f(unpack(args, 1, args.n));
				end, err);
			end
			env.xpcall = newxpcall;
		end;
	end;
	modules["ext.gc"] = function()
		if not newproxy then
			return;
		end
		local gcProxies = setmetatable({}, {__mode="k"});
		local oldsetmetatable = setmetatable;
		function setmetatable(t, mt)
			local oldp = gcProxies[t];
			if oldp then
				getmetatable(oldp).__gc = nil;
			end
			if mt and mt.__gc then
				local p = newproxy(true);
				gcProxies[t] = p;
				getmetatable(p).__gc = function()
					if type(mt.__gc) == "function" then
						mt.__gc(t);
					end
				end;
			end
			return oldsetmetatable(t, mt);
		end
	end;
	function require(n)
		return (modules[n] and modules[n]()) or package.loaded[n];
	end
end)();
return require("ext");
