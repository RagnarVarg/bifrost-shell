.pragma library

// Choose the grid that gives proportional captures the greatest total area.
function layout(windows, width, height, gap, caption) {
    if (!windows.length || width <= 0 || height <= 0) return [];
    let best=[], score=-1;
    for (let columns=1; columns<=windows.length; ++columns) {
        const rows=Math.ceil(windows.length/columns);
        const cw=Math.max(1,(width-gap*(columns-1))/columns);
        const ch=Math.max(1,(height-gap*(rows-1))/rows);
        let area=0;
        const tiles=windows.map((w,i)=>{
            const scale=Math.min(cw/Math.max(1,w.width || 16),Math.max(1,ch-caption)/Math.max(1,w.height || 9));
            const tw=Math.max(1,w.width || 16)*scale, th=Math.max(1,w.height || 9)*scale;
            const count=Math.min(columns,windows.length-Math.floor(i/columns)*columns);
            area+=tw*th;
            return {key:String(w.id),x:(width-count*cw-(count-1)*gap)/2+(i%columns)*(cw+gap)+(cw-tw)/2,
                y:Math.floor(i/columns)*(ch+gap)+(ch-th-caption)/2,width:tw,height:th};
        });
        if (area>score) {score=area;best=tiles;}
    }
    return best;
}
function sync(model, keys) {
    for (let i=model.count-1;i>=0;--i) if (keys.indexOf(model.get(i).key)<0) model.remove(i);
    for (let i=0;i<keys.length;++i) {
        if (i<model.count && model.get(i).key===keys[i]) continue;
        let j=i+1;while(j<model.count && model.get(j).key!==keys[i])++j;
        if(j<model.count)model.move(j,i,1);else model.insert(i,{key:keys[i]});
    }
}

// The windows a monitor's overview shows. selected: null = every window
// (minimized ones included, drawn dimmed), a workspace id, or "minimized".
// A minimized window belongs to the monitor it returns to and to no workspace.
function visible(windows, monitor, selected) {
    return windows.filter(w => w.monitor === monitor && (selected === null || (selected === "minimized" ? w.minimized === true : !w.minimized && w.workspaceId === selected)));
}
