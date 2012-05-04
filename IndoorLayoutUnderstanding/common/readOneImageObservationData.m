function [x] = readOneImageObservationData(imfile, detfiles, boxlayout, vpdata)
%%% prepare all input informations.
x.imfile = imfile;
x.sconf = zeros(3, 1);

img = imread(x.imfile);

rfactor = size(img, 1) ./ vpdata.dim(1);
[ x.K, x.R ]=calibrate_cam(vpdata.vp .* rfactor, size(img, 1), size(img, 2));
%%%% images were rescaled for faster computation

x.lpolys = boxlayout.polyg(boxlayout.reestimated(:, 2), :);
for i = 1:size(x.lpolys, 1)
    for j = 1:size(x.lpolys, 2)
        x.lpolys{i, j} = x.lpolys{i, j} * rfactor;
    end
    [x.faces{i}, x.corners{i}] = getRoomFaces(x.lpolys(i, :), size(img, 1), size(img, 2), x.K, x.R);
end
x.lconf = boxlayout.reestimated(:, 1);

x.dets = zeros(0, 8);
x.locs = zeros(0, 4);
x.cubes = cell(0, 1);
x.projs = struct('rt', cell(0,1), 'poly', cell(0,1));

for i = 1:length(detfiles)
	data = load(detfiles{i});
	dets = parseDets(data, i);
    
    locs = zeros(size(dets, 1), 4);
    cubes = cell(size(dets, 1), 1);
    projs = struct('rt', cell(size(dets, 1), 1), 'poly', []);
    
    fprintf('estimating 3D info of detections, took '); tic();
    for j = 1:size(dets, 1)
        [loc, angle, cube] = get_iproject(x.K, x.R, bbox2rect(dets(j, 4:7)), dets(j, 1:3));
        locs(j, :) = [loc', angle];
        cubes{j} = cube;
        [projs(j).poly, projs(j).rt] = get2DCubeProjection(x.K, x.R, cube);
    end
    toc();
	x.dets = [x.dets; dets];    x.locs = [x.locs; locs];
    x.cubes = [x.cubes; cubes]; x.projs = [x.projs; projs];
end

tic;
x.intvol = sparse(size(x.cubes, 1), size(x.cubes, 1));
for i = 1:size(x.cubes, 1)
    for j = 1:size(x.cubes, 1)
        x.intvol(i, j) = cuboidIntersectionsVolume(x.cubes{i}, x.cubes{j});
    end
end
toc;

tic;
x.orarea = sparse(size(x.dets, 1), size(x.dets, 1));
for i = 1:size(x.dets, 1)
    for j = 1:size(x.dets, 1)
        x.orarea(i, j) = boxoverlap(x.dets(i, 4:7), x.dets(j, 4:7));
    end
end
toc;
end

% [obj type, subtype, pose, x, y, w, h, confidence]
function dets = parseDets(data, idx)

bbox = data.bbox{1};
bbox(:, 1:4) = bbox(:, 1:4) ./ data.resizefactor;
subtypes = unique(bbox(:, 5));
%% filter too low confidences
bbox(bbox(:, end) < -1, :) = [];

temp = [];
for i = 1:length(subtypes)
	tidx = find(bbox(:, 5) == subtypes(i));
	tops = nms2(bbox(tidx, :), 0.65);
	temp = [temp; bbox(tidx(tops), :)];
end
[~, I] = sort(temp(:, end), 'descend');
bbox = temp(I, :);
%%
dets = zeros(size(bbox, 1), 8);

dets(:, 1) = idx;
dets(:, 4:7) = bbox(:, 1:4);
dets(:, 8) = bbox(:, 6);

% view parsing
if(strcmp(data.names{1}, 'sofa8_2'))
	dets(:, 2) = mod(bbox(:, 5) - 1, 2) + 1;
	dets(:, 3) = floor((bbox(:, 5) - 1) ./ 2) .* pi / 4;
elseif(strcmp(data.names{1}, 'table'))
    submodels = [1 2 1 2 1 2 1 2];
    poses = [0 0 pi/4 pi/4 pi/2 pi/2 -pi/4 -pi/4];
    dets(:, 2) = submodels(bbox(:, 5));
    dets(:, 3) = poses(bbox(:, 5));
else
end

end


function [loc, angle, cube] = get_iproject(K, R, rect, attr)

om = objmodels();
pose.subid = attr(2);
pose.az = attr(3);

obj.bbs = rect;
[~, loc] = optimizeOneObject3D(K, R, obj, pose, om(attr(1))); 

angle = getObjAngleFromCamView(loc, pose);
cube = get3DObjectCube(loc, om(attr(1)).width(pose.subid), om(attr(1)).height(pose.subid), om(attr(1)).depth(pose.subid), angle);

end
