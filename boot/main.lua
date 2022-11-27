while true do end
local gpu = component.proxy(component.list("gpu")());

gpu.setDepth(1);
gpu.setBackground(0);
gpu.setForeground(1);
local x, y = gpu.getResolution();
gpu.fill(1, 1, x, y, "A");
