local gpu = component.proxy(component.list("gpu")());
gpu.setDepth(1);
gpu.setBackground(0);
gpu.setForeground(0);
local x, y = gpu.getResolution();
gpu.fill(1, 1, x, y, " ");
gpu.setForeground(1);
gpu.set(1, 1, "cool beans");
while true do end