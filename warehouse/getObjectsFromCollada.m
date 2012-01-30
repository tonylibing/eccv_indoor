function obj = getObjectsFromCollada(filename)

global Collada Geometries LibNodes Positions Triangles;

Collada = xml2struct(filename);

Scene = findNodeByName(Collada, 'scene');

LibNodes = findNodeByName(Collada, 'library_nodes');
Geometries = findNodeByName(Collada, 'library_geometries');

TempNode = findNodeByName(Scene, 'instance_visual_scene');

SearchString = findAttributeValue(TempNode, 'url');

TempNode = findNodeByName(Collada, 'library_visual_scenes');

i = 1;
while (~strcmpi(TempNode.children(i).name, 'visual_scene') && ~strcmpi(TempNode.children(i).id, SearchString))
    i = i + 1;
end
Scene = TempNode.children(i);

ModelFound = 0;
for i = length(Scene.children)-1:-2:2
    if strcmpi(Scene.children(i).name, 'node')
        TempNode = findNodeByName(Scene.children(i), 'instance_camera');
        if isempty(TempNode)
            ModelFound = 1;
            break
        end
    end
end
if ModelFound == 1
    Model = Scene.children(i);
else
    error('no 3D model in the scene');
end
% while length(Model.children) == 3
%     Model = Model.children(1);
% end

for i = 2:2:length(Model.children)-1
    Positions = [];
    Triangles = [];
    Object = Model.children(i);
    [Structure] = getInstanceGeometry(Object);
    obj(round(i/2)).struct.name = Object.id;
    obj(round(i/2)).struct.start = 1;
    obj(round(i/2)).struct.end = size(Positions, 2);
    obj(round(i/2)).struct.struct = Structure;
    obj(round(i/2)).pos = Positions;
    obj(round(i/2)).tri = Triangles';
end
        
                

function out = xml2struct(xmlfile) 
% XML2STRUCT Read an XML file into a MATLAB structure.

xml = xmlread(xmlfile); 

children = xml.getChildNodes; 
for i = 1:children.getLength
    out(i) = node2struct(children.item(i-1)); 
end

function s = node2struct(node)

s.name = char(node.getNodeName); 
s.id = [];
if node.hasAttributes
    attributes = node.getAttributes;
    nattr = attributes.getLength;
    s.attributes = struct('name',cell(1,nattr),'value',cell(1,nattr));

    for i = 1:nattr
        attr = attributes.item(i-1);
        s.attributes(i).name = char(attr.getName);
        s.attributes(i).value = char(attr.getValue);
        if strcmpi(char(attr.getName), 'id')
            s.id = char(attr.getValue);
        end
    end
else
    s.attributes = [];
end

try
    s.data = char(node.getData);
catch
    s.data = '';
end

if node.hasChildNodes
    children = node.getChildNodes;
    nchildren = children.getLength;
    c = cell(1,nchildren);
    s.children = struct('name',c, 'id', c, 'attributes',c,'data',c,'children',c);

    for i = 1:nchildren
        child = children.item(i-1);
        s.children(i) = node2struct(child);
    end
else
    s.children = [];
end 

function OutNode = findNodeByName(InNode, Name)

i = 1;
while ~strcmpi(InNode.children(i).name, Name)
    i = i + 1;
    if i > length(InNode.children)
        break;
    end
end
if i > length(InNode.children)
    OutNode = [];
else
    OutNode = InNode.children(i);
end

function value = findAttributeValue(node, str)

i = 1;
nAttr = length(node.attributes);

while ~strcmpi(node.attributes(i).name, str) || i > nAttr
    i = i + 1;
end
if i <= nAttr
    value = node.attributes(i).value(2:end);
else
    error(['No such attribute as', str]);
end

function OutNode = findNodeById(InNode, str)

i = 1;
while ~strcmpi(InNode.children(i).id, str)
    i = i + 1;
    if i > length(InNode.children)
        break;
    end
end
if i > length(InNode.children)
    OutNode = [];
else
    OutNode = InNode.children(i);
end

function [Structure] = getInstanceGeometry(InNode)

global LibNodes Geometries Positions;
for i = 2:2:length(InNode.children)-1
    if strcmpi(InNode.children(i).name, 'instance_node')
        
        SearchString = findAttributeValue(InNode.children(i), 'url');
        TempNode = findNodeById(LibNodes, SearchString);
        Offset = size(Positions, 2) + 1;
        
        Structure.struct(i).start = Offset;
        [Struct] = getInstanceGeometry(TempNode);
        Structure.struct(i).name = InNode.name;
        Structure.struct(i).end = size(Positions, 2);
        Structure.struct(i).struct = Struct;
        
        MatNode = findNodeByName(InNode, 'matrix');
        Matrix = str2num(MatNode.children.data);
        
        if ~isempty(Matrix)
            Positions(:, Offset:end) = Matrix*Positions(:, Offset:end);
        end
        
    elseif strcmpi(InNode.children(i).name, 'instance_geometry')
        
        SearchString = findAttributeValue(InNode.children(i), 'url');
        InstNode = findNodeById(Geometries, SearchString);
        
        Structure.struct(i).start = size(Positions, 2) + 1;
        appendPositions(InstNode);
        Structure.struct(i).name = InNode.name;
        Structure.struct(i).end = size(Positions, 2);
        Structure.struct(i).struct = [];
        
    elseif strcmpi(InNode.children(i).name, 'node')
        
        Structure.struct(i).start = size(Positions, 2) + 1;
        [Struct] = getInstanceGeometry(InNode.children(i));
        Structure.struct(i).name = InNode.name;
        Structure.struct(i).end = size(Positions, 2);
        Structure.struct(i).struct = Struct;
        
    end
end

function appendPositions(Node)

global Positions Triangles;
Mesh = findNodeByName(Node, 'mesh');
Input = findNodeByName(findNodeByName(Mesh, 'vertices'), 'input');
SearchString = findAttributeValue(Input, 'source');
Source = findNodeById(Mesh, SearchString);
ArrayNode = findNodeByName(Source, 'float_array');
Vector = str2num(ArrayNode.children.data);
Array = ones(4, length(Vector)/3);
Array(1:3, :) = reshape(Vector, 3, length(Vector)/3);
Offset = size(Positions, 2) + 1;
Positions = [Positions Array];
for i = 2:2:length(Mesh.children)
    if strcmpi(Mesh.children(i).name, 'triangles')
        Assign = findNodeByName(Mesh.children(i), 'p');
        AssignVect = str2num(Assign.children.data);
        TriVect = AssignVect(1:3:end);
        TriArray = reshape(TriVect, 3, length(TriVect)/3);
        TriArray = TriArray + Offset;
        Triangles = [Triangles TriArray];
    end
end