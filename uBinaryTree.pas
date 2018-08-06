unit uBinaryTree;

interface

uses SysUtils,Classes,StrUtils,math,contnrs;

// Is there binary tree class on delphi2010?
// 二分木クラス。標準ライブラリにあるならそっちを使いましょう。

type
  TMiscBinaryTreeNodeOnDestroy=procedure(data:pointer) of object;
  TMiscBinaryTreeNode=class
    public
      ParentNode : TMiscBinaryTreeNode;
      LeftNode,RightNode : TMiscBinaryTreeNode;
      Hash : cardinal;
      Data : pointer;
      OnDestory : TMiscBinaryTreeNodeOnDestroy;

      constructor Create;
      destructor  Destroy; override;
      procedure   SwapData(src:TMiscBinaryTreeNode);
      procedure   ReplaceConnect(target:TMiscBinaryTreeNode);
      procedure   DeleteConnect;
  end;
  TMiscBinaryTree=class
    protected
      FRoot : TMiscBinaryTreeNode;
      FCounter : integer;   // add +1 , delete -1 counter
    public
      constructor Create;
      destructor  Destroy; override;

      procedure   Clear;
      procedure   Add(Hash:cardinal; data:pointer; destroycallback:TMiscBinaryTreeNodeOnDestroy=nil);
      function    Delete(node:TMiscBinaryTreeNode):boolean;
      function    Search(node: TMiscBinaryTreeNode; hash:cardinal):TMiscBinaryTreeNode;
      function    SearchNext(node:TMiscBinaryTreeNode; hash:cardinal):TMiscBinaryTreeNode;
      function    IsExists:boolean;

      property    Root:TMiscBinaryTreeNode read FRoot;
      property    Counter : integer read FCounter;      // node exists counter
  end;

// Create BinaryTree data stock class.
// Hashとデータを格納する二分木(BinaryTree)を生成します。
// Allows duplicate hash value.
// Hashの重複を許容します。重複があった場合はLeftNodeに追加されます。
// If find the duplicate hash node , Use SearchNext(now node); function to get the next hash node.
// 重複hashのノードを探す場合は、SearchNext(now node);で次の候補を探します。

// - node add
// MiscBinaryTree.Add(hash , MemoryStream);

// - node search
// node := MiscBinaryTree.Search(MiscBinaryTree.root , hash);
// // next duplicate hash node
// node := MiscBinaryTree.SearchNext(node , hash);

// - node delete
// if MiscBinaryTree.Delete(node) then ShowMessage('delete!');

implementation

{ TMiscBinaryTreeNode }

procedure TMiscBinaryTreeNode.ReplaceConnect(target: TMiscBinaryTreeNode);
var
  p : TMiscBinaryTreeNode;
begin
  p := target.ParentNode;
  // fix from parent link
  if p <> nil then
  begin
    if p.LeftNode  = target then p.LeftNode := self;
    if p.RightNode = target then p.RightNode := self;
  end;
  // fix to parent link
  self.ParentNode := p;

  // fix target link  -->  move to DeleteConnect
  //target.ParentNode := nil;
  //target.LeftNode := nil;
  //target.RightNode := nil;
end;

procedure TMiscBinaryTreeNode.SwapData(src: TMiscBinaryTreeNode);
var
  h : cardinal;
  d : TMiscBinaryTreeNodeOnDestroy;
  p : pointer;
begin
  h := Hash;
  d := OnDestory;
  p := Data;
  Hash := src.Hash;
  OnDestory := src.OnDestory;
  Data := src.Data;
  src.Hash := h;
  src.OnDestory := d;
  src.Data := p;
end;

constructor TMiscBinaryTreeNode.Create;
begin
  OnDestory  := nil;
  ParentNode := nil;
  LeftNode   := nil;
  RightNode  := nil;
  Hash := 0;
  Data := nil;
end;

procedure TMiscBinaryTreeNode.DeleteConnect;
begin
  if ParentNode <> nil then
  begin
    if ParentNode.LeftNode = self then ParentNode.LeftNode := nil;
    if ParentNode.RightNode = self then ParentNode.RightNode := nil;
  end;
  LeftNode := nil;
  RightNode := nil;
end;

destructor TMiscBinaryTreeNode.Destroy;
begin
  if assigned(OnDestory) then OnDestory(data);

  inherited;
end;

{ TMiscBinaryTree }

procedure TMiscBinaryTree.Add(Hash: cardinal; data: pointer; destroycallback: TMiscBinaryTreeNodeOnDestroy);
var
  o,p : TMiscBinaryTreeNode;
begin
  p := nil;
  o := FRoot;

  while true do
  begin
    // add
    if o = nil then
    begin
      o := TMiscBinaryTreeNode.Create;
      o.Hash := Hash;
      o.Data := data;
      o.OnDestory := destroycallback;
      o.ParentNode := p;
      if p = nil then
      begin
        // root
        FRoot := o;
      end
      else
      begin
        // node
        if Hash <= p.Hash then p.LeftNode := o
                          else p.RightNode := o;
      end;
      inc(FCounter);
      break;
    end;
    // left right
    p := o;
    if Hash <= o.Hash then o := o.LeftNode
                      else o := o.RightNode;
  end;
end;

procedure TMiscBinaryTree.Clear;
var
  o,p : TMiscBinaryTreeNode;
begin
  o := FRoot;
  while true do
  begin
    // root.parent
    if o = nil then break;
    // left right
    if o.LeftNode <> nil then
    begin
      o := o.LeftNode;
      continue;
    end;
    if o.RightNode <> nil then
    begin
      o := o.RightNode;
      continue;
    end;
    // free
    p := o.ParentNode;
    o.Free;
    o := p;
  end;

  FRoot := nil;
  FCounter := 0;
end;

constructor TMiscBinaryTree.Create;
begin
  FRoot := nil;
end;

function TMiscBinaryTree.Delete(node: TMiscBinaryTreeNode): boolean;
var
  o : TMiscBinaryTreeNode;
begin
  result := false;
  if node = nil then exit;

  // have left & right node
  if (node.LeftNode <> nil) and (node.RightNode <> nil) then
  begin
    // same value in leftnode
    // get max node in leftNode
    // 同値の扱いにおいて、同値は左ノードに格納されているので、左ノードで最も大きな値を取得する必要がある。
    o := node.LeftNode;
    while true do
    begin
      if o.RightNode = nil then break;
      o := o.RightNode;
    end;
    // data swap
    // 値の入れ替え（リンクは更新しない）
    node.SwapData(o);
    // change delete node
    // (and , terminal node only have one side node.)
    // 終端ノードは片方のノードしか持ちえません。
    node := o;
  end;

  // only have one side node.
  // replace node & fix connection link
  // 片方、ないし両方を持たないノードを木のリンクから外す。
  o := nil;
  if node.LeftNode <> nil then o := node.LeftNode;
  if node.RightNode <> nil then o := node.RightNode;
  if o <> nil then o.ReplaceConnect(node)
              else node.DeleteConnect;
  // root refresh
  if node = FRoot then FRoot := o;

  // free
  node.Free;
  dec(FCounter);

  result := true;
end;

destructor TMiscBinaryTree.Destroy;
begin
  Clear;

  inherited;
end;

function TMiscBinaryTree.IsExists: boolean;
begin
  result := false;
  if FRoot = nil then exit;

  if FRoot.LeftNode <> nil then result := true;
  if FRoot.RightNode <> nil then result := true;
end;

function TMiscBinaryTree.SearchNext(node: TMiscBinaryTreeNode; hash: cardinal): TMiscBinaryTreeNode;
begin
  result := nil;
  if node = nil then exit;

  if node.Hash <= hash then
    result := Search(node.LeftNode,hash)
  else
    result := Search(node.RightNode,hash);
end;

function TMiscBinaryTree.Search(node: TMiscBinaryTreeNode; hash: cardinal): TMiscBinaryTreeNode;
var
  o : TMiscBinaryTreeNode;
begin
  result := nil;
  if node = nil then exit;

  o := node;

  while true do
  begin
    // root.parent or terminate
    if o = nil then break;
    // Hash
    if o.Hash = hash then
    begin
      result := o;
      break;
    end;
    // left right
    if hash <= o.Hash then o := o.LeftNode
                      else o := o.RightNode;
  end;
end;

end.
