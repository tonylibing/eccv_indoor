function pg = GreedyInference(x, iclusters, params, initpg, anno)
% [spg, maxidx, cache, history] = DDMCMCinference(x, iclusters, params, init, anno)
if nargin < 5
    includeloss = false;
    anno = [];
else
    includeloss = true;
end
%% consider upto 50 layouts
% x.lconf(51:end) = [];
% x.lpolys(51:end, :) = [];
% x.faces(51:end) = [];

%%
params.model.w = getweights(params.model);
%% initialize the sample
pg = initpg;
pg.childs = [];

phi = features(pg, x, iclusters, params.model);
pg.lkhood = dot(phi, params.model.w);
if(includeloss)
    pg.loss = lossall(anno, x, pg, params);
end
cache = initCache(pg, x, iclusters, params.model);

%% initialize cache
[moves, cache] = preprocessJumpMoves(x, iclusters, cache);
iter = 0;
while(iter < 20)
    iter = iter + 1;
    
    addidx = find(~cache.inset);
    
    temp = zeros(4, 10000);
    count = 1;
    
    for i = 1:length(addidx)
        newgraph = pg;
        newgraph.childs(end + 1) = addidx(i);
        
        if(isfield(params.model, 'commonground') && params.model.commonground)
            newgraph = findConsistent3DObjects(newgraph, x);
        else
            mh = getAverageObjectsBottom(newgraph, x);
            if(~isnan(mh))
                newgraph.camheight = -mh;
            else
                newgraph.camheight = 1.5;
            end
        end
                
        temp(1, count) = 1;
        phi = features(newgraph, x, iclusters, params.model);
        temp(2, count) = dot(phi, params.model.w) - pg.lkhood;
        if(includeloss)
            newgraph.loss = lossall(anno, x, newgraph, params);
            temp(2, count) = temp(2, count) + newgraph.loss - pg.loss;
        end
        temp(3, count) = addidx(i);
        count = count + 1;
    end
    
    if(strcmp(params.inference, 'greedy'))
        swidx = find(cache.inset);
        for i = 1:length(swidx)
            delidx = swidx(i);
            addset = cache.swset{delidx};

            tempidx = find(pg.childs == delidx, 1);

            for j = 1:length(addset)
                newgraph = pg;
                if(cache.inset(addset(j)))
                    continue;
                end
                newgraph.childs(tempidx) = addset(j);

                obts = [];
                for k = newgraph.childs(:)'
                    obts = [obts, min(x.cubes{k}(2, :))];
                end

                if(isempty(obts))
%                     newgraph.camheight = 1.0;
                else
%                     newgraph.camheight = -mean(obts);
                end

                temp(1, count) = 2;
                phi = features(newgraph, x, iclusters, params.model);
                temp(2, count) = dot(phi, params.model.w)  - pg.lkhood;
                if(includeloss)
                    newgraph.loss = lossall(anno, x, newgraph, params);
                    temp(2, count) = temp(2, count) + newgraph.loss - pg.loss;
                end
                temp(3, count) = delidx;
                temp(4, count) = addset(j);

                count = count + 1;
            end
        end
    end
    temp(:, count:end) = [];
    
    temp = temp(:, temp(2, :) > 0);
    
    if(isempty(temp))
        % no more addition.
        break;
    end
    [~, select] = max(temp(2, :));
    
    if(temp(1, select) == 1)
        addidx = temp(3, select);
        assert(~cache.inset(addidx));
        
        newgraph = pg;
        newgraph.childs(end + 1) = addidx;
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        cache.inset(addidx) = true;
    elseif(temp(1, select) == 2)
        delidx = temp(3, select);
        addidx = temp(4, select);
        
        assert(cache.inset(delidx));
        assert(~cache.inset(addidx));
        
        newgraph = pg;
        newgraph.childs(find(newgraph.childs == delidx, 1)) = addidx;
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        cache.inset(delidx) = false;
        cache.inset(addidx) = true;
    end
%     obts = [];
%     for j = newgraph.childs(:)'
%         obts = [obts, min(x.cubes{j}(2, :))];
%     end
    mh = getAverageObjectsBottom(newgraph, x);
    if(~includeloss)
        newgraph.camheight = -mh;
    end
%     newgraph.camheight = -mean(obts);

    phi = features(newgraph, x, iclusters, params.model);
    newgraph.lkhood = dot(phi, params.model.w);
    if(includeloss)
        newgraph.loss = lossall(anno, x, newgraph, params);
    end

    pg = newgraph;
end


end

function cache = initCache(pg, x, iclusters, model)
cache = mcmccache(length(iclusters), length(x.lconf));

cache.inset(pg.childs) = true;
%% init cache
cache.playout = exp(x.lconf .* model.w_or);
cache.playout = cache.playout ./ sum(cache.playout);
cache.clayout = cumsum(cache.playout);

cache.padd = exp(x.dets(:, end) .* model.w_oo(1));
end