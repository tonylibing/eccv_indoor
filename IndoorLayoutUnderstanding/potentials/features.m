function phi = features(pg, x, iclusters, model)

if( isfield(model, 'commonground') && model.commonground )
    phi = features3(pg, x, iclusters, model);
    return;
end

if(~isfield(model, 'feattype') || strcmp(model.feattype, 'type1'))
    phi = features1(pg, x, iclusters, model);
elseif(strcmp(model.feattype, 'type2'))
    phi = features2(pg, x, iclusters, model);
end

end

function phi = features3(pg, x, iclusters, model)
featlen =   1 + ... % layout confidence : no bias required, selection problem    
            2 + ... % object-object interaction : 1) 3D intersection 2) 2D bboverlap
            3 * (length(model.ow_edge) - 1) + ... % object-wall inclusion 
            model.nobjs + ... % min distance to wall 3D
            model.nobjs + ... % min distance to wall 2D
            model.nobjs + ... % floor distance per object: sofa to floor
            2 * model.nobjs;      % object confidence : (weight + bias) per type

phi = zeros(featlen, 1);
ibase = 1;

assert(isfield(pg, 'objscale'));
cubes = cell(1, length(pg.childs));
for i = 1:length(pg.childs)
    idx = pg.childs(i);
    cubes{i} = x.cubes{idx} .* pg.objscale(i);
end

%% scene
% layout confidence
phi(ibase) = x.lconf(pg.layoutidx);
ibase = ibase + 1;

%% for a pair of objects
% per object definition??
% object interaction - repulsion
for i = 1:length(pg.childs)
    for j = i+1:length(pg.childs)
        % not supporting grouping yet!
        i1 = pg.childs(i);
        i2 = pg.childs(j);
        
        assert(iclusters(i1).isterminal);
        assert(iclusters(i2).isterminal);
        
        phi(ibase) = phi(ibase) + cuboidIntersectionsVolume(cubes{i}, cubes{j});
        phi(ibase + 1) = phi(ibase + 1) + x.orarea(i1, i2);
    end
end
ibase = ibase + 2;

%% below : all per object!
% object-room face interaction - no inclusion
buf_f = zeros(length(pg.childs), 1);
buf_c = zeros(length(pg.childs), 1);
buf_w = zeros(3 * length(pg.childs), 1);
for i = 1:length(cubes)
    %%%%%% need to make it robust!!!
    volume = cuboidRoomIntersection(x.faces{pg.layoutidx}, pg.camheight, cubes{i});
    
    buf_f(i) = volume(1);
    buf_c(i) = volume(5);
    buf_w((3*i-2):3*i) = volume(2:4);
end
temp = histc(buf_f, model.ow_edge);
phi(ibase:ibase+(length(model.ow_edge) - 2)) = temp(1:end-1);
ibase = ibase + length(model.ow_edge) - 1;

temp = histc(buf_c, model.ow_edge);
phi(ibase:ibase+(length(model.ow_edge) - 2)) = temp(1:end-1);
ibase = ibase + length(model.ow_edge) - 1;

temp = histc(buf_w, model.ow_edge);
phi(ibase:ibase+(length(model.ow_edge) - 2)) = temp(1:end-1);
ibase = ibase + length(model.ow_edge) - 1;

% object-wall interaction % min distance to wall 3D
% for i = 1:length(pg.childs)
%     i1 = pg.childs(i);
%     assert(iclusters(i1).isterminal);
%     [d1, d2] = obj2wallFloorDist(x.faces{pg.layoutidx}, x.cubes{i1}, pg.camheight);
%     oid = iclusters(i1).ittype - 1;
%     phi(ibase+oid) = phi(ibase+oid) + min(abs(d1) + abs(d2));
% end
ibase = ibase + model.nobjs;

% object-wall interaction % min distance to wall 2D
% for i = 1:length(pg.childs)
%     i1 = pg.childs(i);
%     assert(iclusters(i1).isterminal);
%     [d1, d2] = obj2wallImageDist(x.corners{pg.layoutidx}, x.projs(i1).poly);
%     oid = iclusters(i1).ittype - 1;
%     
%     phi(ibase+oid) = phi(ibase+oid) + min(d1 + d2);
% end
ibase = ibase + model.nobjs;

% object-floor interaction 
for i = 1:length(pg.childs)
    i1 = pg.childs(i);
    assert(iclusters(i1).isterminal);
    oid = iclusters(i1).ittype - 1;
    
    bottom = min(cubes{i}(2, :)); % bottom y position.
    
    phi(ibase+oid) = phi(ibase+oid) + (pg.camheight + bottom) .^ 2; %
end
ibase = ibase + model.nobjs;

% object observation confidence + bias
for i = 1:length(pg.childs)
    i1 = pg.childs(i);
    assert(iclusters(i1).isterminal);
    
    oid = (iclusters(i1).ittype - 1) * 2;
    phi(ibase + oid) = phi(ibase + oid) + x.dets(i1, 8);
    phi(ibase + oid + 1) = phi(ibase + oid + 1) + 1;
end
ibase = ibase + 2 * model.nobjs;
assert(featlen == ibase - 1);

if(any(isnan(phi)) || any(isinf(phi)))
    keyboard;
end

end

function phi = features2(pg, x, iclusters, model)
featlen =   1 + ... % layout confidence : no bias required, selection problem    
            2 + ... % object-object interaction : 1) 3D intersection 2) 2D bboverlap
            3 * (length(model.ow_edge) - 1) + ... % object-wall inclusion 
            model.nobjs + ... % min distance to wall 3D
            model.nobjs + ... % min distance to wall 2D
            model.nobjs + ... % floor distance per object: sofa to floor
            2 * model.nobjs;      % object confidence : (weight + bias) per type

phi = zeros(featlen, 1);
ibase = 1;
%% scene
% layout confidence
phi(ibase) = x.lconf(pg.layoutidx);
ibase = ibase + 1;
%% for a pair of objects
% per object definition??
% object interaction - repulsion
for i = 1:length(pg.childs)
    for j = i+1:length(pg.childs)
        % not supporting grouping yet!
        i1 = pg.childs(i);
        i2 = pg.childs(j);
        
        assert(iclusters(i1).isterminal);
        assert(iclusters(i2).isterminal);
        
        phi(ibase) = phi(ibase) + x.intvol(i1, i2);
        phi(ibase + 1) = phi(ibase + 1) + x.orarea(i1, i2);
    end
end
ibase = ibase + 2;

%% below : all per object!
% object-room face interaction - no inclusion
buf_f = zeros(length(pg.childs), 1);
buf_c = zeros(length(pg.childs), 1);
buf_w = zeros(3 * length(pg.childs), 1);

for i = 1:length(pg.childs)
    i1 = pg.childs(i);
    assert(iclusters(i1).isterminal);
    %%%%%% need to make it robust!!!
    volume = cuboidRoomIntersection(x.faces{pg.layoutidx}, pg.camheight, x.cubes{i1});
    
    buf_f(i) = volume(1);
    buf_c(i) = volume(5);
    buf_w((3*i-2):3*i) = volume(2:4);
end
temp = histc(buf_f, model.ow_edge);
phi(ibase:ibase+(length(model.ow_edge) - 2)) = temp(1:end-1);
ibase = ibase + length(model.ow_edge) - 1;

temp = histc(buf_c, model.ow_edge);
phi(ibase:ibase+(length(model.ow_edge) - 2)) = temp(1:end-1);
ibase = ibase + length(model.ow_edge) - 1;

temp = histc(buf_w, model.ow_edge);
phi(ibase:ibase+(length(model.ow_edge) - 2)) = temp(1:end-1);
ibase = ibase + length(model.ow_edge) - 1;

% object-wall interaction % min distance to wall 3D
% for i = 1:length(pg.childs)
%     i1 = pg.childs(i);
%     assert(iclusters(i1).isterminal);
%     [d1, d2] = obj2wallFloorDist(x.faces{pg.layoutidx}, x.cubes{i1}, pg.camheight);
%     oid = iclusters(i1).ittype - 1;
%     phi(ibase+oid) = phi(ibase+oid) + min(abs(d1) + abs(d2));
% end
ibase = ibase + model.nobjs;

% object-wall interaction % min distance to wall 2D
% for i = 1:length(pg.childs)
%     i1 = pg.childs(i);
%     assert(iclusters(i1).isterminal);
%     [d1, d2] = obj2wallImageDist(x.corners{pg.layoutidx}, x.projs(i1).poly);
%     oid = iclusters(i1).ittype - 1;
%     
%     phi(ibase+oid) = phi(ibase+oid) + min(d1 + d2);
% end
ibase = ibase + model.nobjs;

% object-floor interaction 
for i = 1:length(pg.childs)
    i1 = pg.childs(i);
    assert(iclusters(i1).isterminal);
    
    bottom = x.cubes{i1}(2, 1); % bottom y position.
    oid = iclusters(i1).ittype - 1;
    
    phi(ibase+oid) = phi(ibase+oid) + (pg.camheight + bottom) .^ 2; %
end
ibase = ibase + model.nobjs;

% object observation confidence + bias
for i = 1:length(pg.childs)
    i1 = pg.childs(i);
    assert(iclusters(i1).isterminal);
    
    oid = (iclusters(i1).ittype - 1) * 2;
    phi(ibase + oid) = phi(ibase + oid) + x.dets(i1, 8);
    phi(ibase + oid + 1) = phi(ibase + oid + 1) + 1;
end
ibase = ibase + 2 * model.nobjs;
assert(featlen == ibase - 1);

if(any(isnan(phi)) || any(isinf(phi)))
    keyboard;
end

end

function phi = features1(pg, x, iclusters, model)
featlen =   1 + ... % layout confidence : no bias required, selection problem    
            2 + ... % object-object interaction : 1) 3D intersection 2) 2D bboverlap
            5 + ... % object inclusion : 3D volume intersection
            model.nobjs + ... % min distance to wall 3D
            model.nobjs + ... % min distance to wall 2D
            model.nobjs + ... % floor distance per object: sofa to floor
            2 * model.nobjs;      % object confidence : (weight + bias) per type


phi = zeros(featlen, 1);
ibase = 1;

%% scene
% layout confidence
phi(ibase) = x.lconf(pg.layoutidx);
ibase = ibase + 1;
%% for a pair of objects
% per object definition??
% object interaction - repulsion
for i = 1:length(pg.childs)
    for j = i+1:length(pg.childs)
        % not supporting grouping yet!
        i1 = pg.childs(i);
        i2 = pg.childs(j);
        
        assert(iclusters(i1).isterminal);
        assert(iclusters(i2).isterminal);
        
        phi(ibase) = phi(ibase) + x.intvol(i1, i2);
        phi(ibase + 1) = phi(ibase + 1) + x.orarea(i1, i2);
    end
end
ibase = ibase + 2;
%% below : all per object!
% object-room face interaction - no inclusion
for i = 1:length(pg.childs)
    i1 = pg.childs(i);
    assert(iclusters(i1).isterminal);
    %%%%%% need to make it robust!!!
    volume = cuboidRoomIntersection(x.faces{pg.layoutidx}, pg.camheight, x.cubes{i1});
    phi(ibase:ibase+4) = phi(ibase:ibase+4) + volume;
end
ibase = ibase + 5;

% object-wall interaction % min distance to wall 3D
% for i = 1:length(pg.childs)
%     i1 = pg.childs(i);
%     assert(iclusters(i1).isterminal);
%     [d1, d2] = obj2wallFloorDist(x.faces{pg.layoutidx}, x.cubes{i1}, pg.camheight);
%     oid = iclusters(i1).ittype - 1;
%     phi(ibase+oid) = phi(ibase+oid) + min(abs(d1) + abs(d2));
% end
ibase = ibase + model.nobjs;

% object-wall interaction % min distance to wall 2D
% for i = 1:length(pg.childs)
%     i1 = pg.childs(i);
%     assert(iclusters(i1).isterminal);
%     [d1, d2] = obj2wallImageDist(x.corners{pg.layoutidx}, x.projs(i1).poly);
%     oid = iclusters(i1).ittype - 1;
%     
%     phi(ibase+oid) = phi(ibase+oid) + min(d1 + d2);
% end
ibase = ibase + model.nobjs;

% object-floor interaction 
for i = 1:length(pg.childs)
    i1 = pg.childs(i);
    assert(iclusters(i1).isterminal);
    
    bottom = x.cubes{i1}(2, 1); % bottom y position.
    oid = iclusters(i1).ittype - 1;
    
    phi(ibase+oid) = phi(ibase+oid) + (pg.camheight + bottom) .^ 2; %
end
ibase = ibase + model.nobjs;

% object observation confidence + bias
for i = 1:length(pg.childs)
    i1 = pg.childs(i);
    assert(iclusters(i1).isterminal);
    
    oid = (iclusters(i1).ittype - 1) * 2;
    phi(ibase + oid) = phi(ibase + oid) + x.dets(i1, 8);
    phi(ibase + oid + 1) = phi(ibase + oid + 1) + 1;
end
ibase = ibase + 2 * model.nobjs;
assert(featlen == ibase - 1);

if(any(isnan(phi)) || any(isinf(phi)))
    keyboard;
end

end

% NClusterType = model.nobjs + length(model.rules);
% phi = zeros(model.nscene * NClusterType + ...
%             0, 1);
% % compatibility between cluster and scene 
% % function of cluster type and room type.
% ibase = 0;
% for i = 1:length(pg.childs)
%     idx = ibase + (pg.scenetype - 1) * NClusterType;
%     idx = idx + iclusters(pg.childs(i)).ittype;
%     
%     phi(idx) = phi(idx) + 1;
% end
% ibase = ibase + model.nscene * NClusterType;
% % geometric compatibility between clusters and scene layout
% % function of camera height, room faces, clusters
% 
% % compatibility between clusters and childs
% % 
% 
% % observation
% % scene, layout, objects
% end
