function [pixerr]=getPixerr(gtPolyg,Polyg)
% farea1=farea;
farea1=zeros(1,5);
farea2=zeros(1,5);
for i=1:numel(gtPolyg)
    
    if size(gtPolyg{i},1)>0
        farea1(i)=polyarea([gtPolyg{i}(:,1);gtPolyg{i}(1,1)],[gtPolyg{i}(:,2);gtPolyg{i}(1,2)]);
    end
    
    if size(Polyg{i},1)>0
        farea2(i)=polyarea([Polyg{i}(:,1);Polyg{i}(1,1)],[Polyg{i}(:,2);Polyg{i}(1,2)]);
        
    end
end

cnt=0;
err=[];
% Find intersection area of fields
for i=1:5
    
    if farea1(i)== 0 & farea2(i)==0
        %if both the fields are invisible dont count
        continue;
    elseif farea1(i)>0 & farea2(i)==0
        cnt=cnt+1;
        nInter=0;
    elseif farea1(i)== 0 & farea2(i)>0
        cnt=cnt+1;
        nInter=0;
    else        % farea1(i)>0 & farea2(i)>0
        cnt=cnt+1;
        
        XX1=Polyg{i}(:,1);YY1=Polyg{i}(:,2); %get the polygon
        YY2=gtPolyg{i}(:,2);XX2=gtPolyg{i}(:,1);
        in1=inpolygon(XX1,YY1,[XX2;XX2(1)],[YY2;YY2(1)]);
        in2=inpolygon(XX2,YY2,[XX1;XX1(1)],[YY1;YY1(1)]);
        
        if numel(find(in1==1))==length(in1)
            X0=XX1;Y0=YY1;
        elseif numel(find(in2==1))==length(in2)
            X0=XX2;Y0=YY2;
        else
            [in,on]=inpolygon(XX2,YY2,[XX1;XX1(1)],[YY1;YY1(1)]);
            XX2(find(on)) = XX2(find(on))+1;
            YY2(find(on)) = YY2(find(on))+1;
            [in,on]=inpolygon(XX1,YY1,[XX2;XX2(1)],[YY2;YY2(1)]);;
            XX1(find(on)) = XX1(find(on))+1;
            YY1(find(on)) = YY1(find(on))+1;
%             [X0 Y0 ind]=polyints(XX1,YY1,XX2,YY2); %remember to check polybool
            [X0 Y0] = polybool('intersection',XX1,YY1,XX2,YY2); 
        end
        if numel(X0)>0
            nInter=polyarea([X0; X0(1)],[Y0;Y0(1)]);
            
        else
            nInter=0;
        end
    end
    %     nInter;
    Fdiff(cnt)=1-nInter/(farea1(i)+farea2(i)-nInter);
    err(cnt)=farea1(i)-nInter;
end

% pixerr1=mean(Fdiff);
pixerr=sum(err)/sum(farea1);
return;
