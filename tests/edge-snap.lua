-- Run from the repository root: lua tests/edge-snap.lua
local win = { address = "0x1", floating = true, at = { x = 300, y = 200 }, size = { x = 800, y = 600 }, monitor = {name="TEST",x=0,y=0,width=1920,height=1080,reserved={left=0,right=0,top=0,bottom=0}} }
local binds, gesture, commands = {}, nil, {}
local function dispatch(spec)
    local p=spec.params
    if spec.kind == 'resize' then win.size={x=p.x,y=p.y} end
    if spec.kind == 'move' and p.x then
        win.at={x=p.relative and win.at.x+p.x or p.x,y=p.relative and win.at.y+p.y or p.y}
    end
end
hl = {
 exec_cmd=function(s) table.insert(commands,s) end,
 get_cursor_pos=function() return {x=500,y=400} end,
 get_windows=function() return {win} end,
 get_window=function() return win end,
 get_active_window=function() return win end,
 dispatch=dispatch,
 unbind=function() end,
 bind=function(_,f,opt) binds[opt.release and 'release' or 'press']=f end,
 timer=function(f) return {stop=function() end, tick=f} end,
 gesture=function(g) if type(g.action)=='table' then gesture=g.action end end,
 dsp={window={}}
}
for _,k in ipairs({'move','resize','drag'}) do hl.dsp.window[k]=function(p) return {kind=k,params=p or {}} end end
os.getenv=function(k) if k=='XDG_RUNTIME_DIR' then return '/tmp/bifrost-test-runtime' end end
dofile('config/hypr/config/edge-snap.lua')
assert(gesture and binds.press and binds.release)
gesture.start({})
gesture.update({delta={x=-300,y=0}})
assert(win.size.x==800, 'Must not snap before release')
assert(commands[#commands]:find('TEST'), 'Must show preview')
gesture.finish({cancelled=false})
assert(win.size.x==958 and win.at.x==0, 'Left half')
gesture.start({})
assert(win.size.x==800 and win.size.y==600, 'Restore original size')
gesture.update({delta={x=1120-win.at.x,y=0}})
gesture.finish({cancelled=false})
assert(win.at.x==962 and win.size.x==958, 'Right half and shared border midpoint')
gesture.start({})
gesture.update({delta={x=-win.at.x,y=0}})
gesture.finish({cancelled=true})
assert(win.size.x==800, 'Cancelled gesture must not snap')
binds.press()
win.at.x=0
_G.__dmsMouseDrag.timer.tick()
assert(win.size.x==800, 'Mouse pause is not release')
binds.release()
assert(win.size.x==958, 'Mouse release snaps')
print('PASS: preview, gesture release/cancel, restore size, shared midpoint, mouse release')
