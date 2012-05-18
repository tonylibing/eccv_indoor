function [p, ua] = lineintersection(p1, p2, p3, p4)
% l1 : p1 - p2
% l2 : p3 - p4
ua = ((p4(1) - p3(1)) * (p1(2) - p3(2)) - (p4(2) - p3(2)) * (p1(1) - p3(1))) / ...
     ((p4(2) - p3(2)) * (p2(1) - p1(1)) - (p4(1) - p3(1)) * (p2(2) - p1(2)));
 
% ub = ((x2 - x1) * (y1 - y3) - (y2 - y1) * (x1 - x3)) / ...
%      ((y4 - y3) * (x2 - x1) - (x4 - x3) * (y2 - y1)); 

p = p1 + ua * ( p2 - p1 );
% y = p1(2) + ua * ( p2(2) - p1(2) );

end