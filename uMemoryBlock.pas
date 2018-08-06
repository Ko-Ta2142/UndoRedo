unit uMemoryBlock;

interface

uses SysUtils,Classes,StrUtils,math,uBinaryTree;

{$R-}  //RangeErrorCheck OFF

type
  TMemoryBlockData=class;
  // callback
  TMemoryBlockOnDestroy = procedure(block:TMemoryBlockData) of object;
  // block
  // same memory block optimize class. do not create!
  // 同一メモリ最適化クラス。手動で生成しないでください。
  TMemoryBlockData=class
  private
    protected
      FRef : integer;
      FData : TMemoryStream;
      FHash : cardinal;
      FOnDestroy : TMemoryBlockOnDestroy;
    public
      constructor Create;
      destructor  Destroy; override;
      procedure   SetData(sptr:pointer; size:integer);
      function    Compare(sptr:pointer; size:integer):boolean; overload;
      function    Compare(other:TMemoryBlockData):boolean; overload; inline;
      function    Replicate:TMemoryBlockData; inline;
      // ref
      procedure   AddRef;
      function    Release:boolean;

      property    Hash : cardinal read FHash;
      property    Data : TMemoryStream read FData;
      property    OnDestroy : TMemoryBlockOnDestroy read FOnDestroy write FOnDestroy;
      property    Reference : integer read FRef;
  end;
  // controller
  // TMemoryBlockData manage & controller class. do not create!
  // TMemoryBlockData操作用クラス。手動で生成しないでください。
  TMemoryBlockObject=class
    protected
      FBlock : TMemoryBlockData;
    public
      constructor Create(block:TMemoryBlockData);
      destructor  Destroy; override;
      function    Replicate:TMemoryBlockObject;

      function    Data : TMemoryStream; inline;
      function    Size : integer;       inline;
      function    Memory : pointer;     inline;
      property    MemoryBlock : TMemoryBlockData read FBlock;
  end;
  // pool
  // TMemoryBlockData manage & pool class. getobject
  // TMemoryBlockData管理用クラス。
  TMemoryBlockPool=class
    protected
      FBlocks : TMiscBinaryTree;
      FHashFileSizeLimit : integer;
      FCompactionCount : integer;
      FCounter : integer;
      function    SearchBlock(hash:cardinal; sptr:pointer; size:integer):TMemoryBlockData;
      procedure   OnDestoryCallback(block:TMemoryBlockData);
    public
      constructor Create;
      destructor  Destroy; override;
      // data set/get
      // return TMemoryBlockObject. slow for class create.
      // 操作用TMemoryBlockObjectを返すので便利ですが、クラス生成するので遅めです。
      function    GetObject(ms:TMemoryStream; AddRef:boolean=true):TMemoryBlockObject; overload;
      function    GetObject(sptr:pointer; size:integer; AddRef:boolean=true):TMemoryBlockObject; overload;
      // return TMemoryBlockData. faster than GetObject function.
      // TMemoryBlockDataをそのままを返します。扱いづらいですがクラス生成がないので高速です。大量のデータを扱う際に有効です。
      function    GetBlock(ms:TMemoryStream; AddRef:boolean=true):TMemoryBlockData; overload; inline;
      function    GetBlock(sptr:pointer; size:integer; AddRef:boolean=true):TMemoryBlockData; overload;
      // do not use TMemoryBlock.free. use(call) FreeBlock function.
      // TMemoryBlockDataが不要になったらFreeBlockを安全のために使ってください。
      procedure   FreeBlock(o:TMemoryBlockData); inline;
      // debug
      function    GetBlockList : TList;

      property    HashFileSizeLimit:integer read FHashFileSizeLimit write FHashFileSizeLimit;
      property    Counter:integer read FCounter;    // MemoryBlock exists counter
  end;

// how to use

// Optimize(refer to the same class) the duplicate MemoryStream data.
// 重複するMemoryStreamデータを最適化（同一クラスを参照）します。
// Do not change after registering MemoryStream class.
// 登録後にMemoryStreamの変更は行わないでください。
// Ideal for undo redo data.
// Undo Redo のような一部以外同じデータを大量に保持する場合に効果を発揮します。

// - first , create / free MemoryBlockPool

// MemoryBlockPool := TMemoryBlockPool.Create;
// ...
// MemoryBlockPool.Free;

// - get & free MemoryBlockObject(controller)

// o := MemoryBlockPool.GetObject(ms);
// ...
// o.free;

// - optimize MemoryStream

// ms1 := TMemoryStream.Create;
// ms2 := TMemoryStream.Create;
// ms1.LoadFromFile('aaaa.txt');  // duplicate data
// ms2.LoadFromFile('aaaa.txt');  // duplicate data.
// o1 := MemoryBlockPool.GetObject(ms1);
// o2 := MemoryBlockPool.GetObject(ms2);   // optimize! o1.Memory = o2.Memory
// ms1.free;
// ms2.free;
// ...
// temp := o1.Data;   // TMemoryStream class
// sptr := o1.Memory; // memory pointer. MemoryStream.Memory;
// size := o1.Size;   // memory length size. MemoryStream.Size;
// if o1.data = o2.data // compare data. do not need memory compare. compare pointer is enough.
// ...
// o1.free;
// o2.free;

// - if handling a large amount of data.
// use GetBlock function. It's fast and lite memory.
// もし大量のデータを扱うなら、GetBlockを使った方がコントローラクラスを生成しないので高速＆メモリに優しいです。

// for i:=0 to 256-1 do
//   o[i] := MemoryBlockPool.GetBlock(MemoryStreamData[i]);
// ...
// ms := o[0].Data;  // TMemoryStream class.
// ...
// for i:=0 to 256-1 do
//   MemoryBlockPool.FreeBlock(o[i]);  // or TMemoryBlock(o[i]).Release;


implementation

function _MakeHash(mem:pointer; size:integer):cardinal;
var
  i : integer;
  c1,c2,c3 : cardinal;
  sptr : pbyte;
  l4,l1 : integer;
begin
  l4 := size div 4;
  l1 := size and 3;

  sptr := mem;
  // 4byte
  c3 := $ef32456;
  for i:=0 to l4-1 do
  begin
    c1 := pcardinal(sptr)^;
    c2 := c1;
    c1 := c1 shr 3;
    c2 := c2 shl 3;
    c1 := c1 xor c2;
    c3 := c3 + c1;        // range over
    inc(sptr,4);
  end;
  // 1byte
  for i:=0 to l1-1 do
  begin
    c1 := sptr^;
    c2 := c1;
    c1 := c1 shr 3;
    c2 := c2 shl 3;
    c1 := c1 xor c2;
    c3 := c3 + c1;        // range over
    inc(sptr,1);
  end;

  result := c3;
end;

{ TMemoryBlockPool }

constructor TMemoryBlockPool.Create;
begin
  FBlocks := TMiscBinaryTree.Create;
  FHashFileSizeLimit := 1024*1024*16;
end;

destructor TMemoryBlockPool.Destroy;
begin
  if FCounter <> 0 then
  begin
    raise Exception.Create('TMemoryPool.Destory : Warning! Unreleased block Exists. : ' + IntToStr(FCounter) + ' blocks');
  end;

  FBlocks.Free;

  inherited;
end;

procedure TMemoryBlockPool.FreeBlock(o: TMemoryBlockData);
begin
  if o <> nil then o.Release;
end;

function TMemoryBlockPool.GetObject(ms: TMemoryStream; addref:boolean): TMemoryBlockObject;
var
  block : TMemoryBlockData;
begin
  result := nil;
  block := GetBlock(ms,AddRef);
  if block <> nil then result := TMemoryBlockObject.Create(block);
end;

function TMemoryBlockPool.GetObject(sptr: pointer; size: integer; addref:boolean): TMemoryBlockObject;
var
  block : TMemoryBlockData;
begin
  result := nil;
  block := GetBlock(sptr,size,AddRef);
  if block <> nil then result := TMemoryBlockObject.Create(block);
end;

function TMemoryBlockPool.GetBlock(ms: TMemoryStream; AddRef: boolean): TMemoryBlockData;
begin
  result := GetBlock(ms.Memory,ms.Size , AddRef);
end;

function TMemoryBlockPool.GetBlock(sptr: pointer; size: integer; AddRef: boolean): TMemoryBlockData;
var
  hash : cardinal;
  block : TMemoryBlockData;
begin
  result := nil;
  hash := _MakeHash(sptr,size);
  block := SearchBlock(hash,sptr,size);

  if block = nil then
  begin
    // lock create. need addref enable.
    if not(addref)then exit;
    // none
    block := TMemoryBlockData.Create;
    block.SetData(sptr,size);
    block.AddRef;
    block.OnDestroy := OnDestoryCallback; // destroy callback
    // search list add
    FBlocks.Add(hash,pointer(block));
    inc(FCounter);
  end
  else
  begin
    // exists
    if AddRef then block.AddRef;
  end;

  result := block;
end;

function TMemoryBlockPool.GetBlockList: TList;
  procedure inNode(list:TList; const node:TMiscBinaryTreeNode);
  begin
    if node = nil then exit;
    list.Add(node.Data);
    if node.LeftNode <> nil then inNode(list,node.LeftNode);
    if node.RightNode <> nil then inNode(list,node.RightNode);
  end;
var
  list : TList;
  node : TMiscBinaryTreeNode;
begin
  list := TList.Create;
  inNode(list,FBlocks.Root);
  result := list;
end;

procedure TMemoryBlockPool.OnDestoryCallback(block: TMemoryBlockData);
var
  node : TMiscBinaryTreeNode;
begin
  node := FBlocks.Search(FBlocks.Root,block.hash);

  while true do
  begin
    if node = nil then break;

    if node.Data = pointer(block) then
    begin
      FBlocks.Delete(node);
      dec(FCounter);
      exit;
    end;

    // next
    node := FBlocks.SearchNext(node,block.hash);
  end;

  // error
  raise Exception.Create('TMemoryBolockPool.OnDestoryCallback : Error! MemoryBlock not found in this pool.');
end;

function TMemoryBlockPool.SearchBlock(hash: cardinal; sptr: pointer; size: integer): TMemoryBlockData;
var
  o : TMemoryBlockData;
  node : TMiscBinaryTreeNode;
begin
  result := nil;

  node := FBlocks.Search(FBlocks.Root,hash);
  while true do
  begin
    if node = nil then break;

    o := TMemoryBlockData(node.Data);
    if o.Compare(sptr,size)then
    begin
      result := o;
      break;
    end;

    // next
    node := FBlocks.SearchNext(node,hash);
  end;
end;

{ TMemoryBlockData }

procedure TMemoryBlockData.AddRef;
begin
  inc(FRef);
end;

function TMemoryBlockData.Compare(sptr: pointer; size: integer):boolean;
begin
  result := false;
  if FData = nil then exit;
  if FData.Size <> size then exit;

  if size = 0 then
    result := true
  else
    result := CompareMem(sptr,FData.Memory , size);
end;

function TMemoryBlockData.Compare(other: TMemoryBlockData): boolean;
begin
  result := other = self;
end;

constructor TMemoryBlockData.Create;
begin
  FRef := 0;
  FData := nil;
  FHash := 0;
end;

destructor TMemoryBlockData.Destroy;
begin
  if data <> nil then data.Free;

  inherited;
end;

function TMemoryBlockData.Replicate: TMemoryBlockData;
begin
  AddRef;
  result := self;
end;

function TMemoryBlockData.Release:boolean;
begin
  result := false;

  dec(FRef);
  if FRef < 1 then
  begin
    result := true;
    if assigned(FOnDestroy) then FOnDestroy(self);   // call owner(MemoryBlockPool) function
    self.Free;
  end;
end;

procedure TMemoryBlockData.SetData(sptr:pointer; size:integer);
begin
  FData := TMemoryStream.Create;
  FData.SetSize(size);
  if size > 0 then move(sptr^,Fdata.Memory^ , size);

  FHash := _MakeHash(sptr,size);
end;

{ TMemoryBlockObject }

constructor TMemoryBlockObject.Create(block:TMemoryBlockData);
begin
  FBlock := block;
end;


destructor TMemoryBlockObject.Destroy;
begin
  if FBlock <> nil then
  begin
    FBlock.Release;
    //if FBlock.Release then FBlock.Free;
  end;

  inherited;
end;

function TMemoryBlockObject.Data: TMemoryStream;
begin
  result := FBlock.Data;
end;

function TMemoryBlockObject.Memory:pointer;
begin
  result := FBlock.Data.Memory;
end;

function TMemoryBlockObject.Replicate: TMemoryBlockObject;
var
  o : TMemoryBlockObject;
begin
  o := TMemoryBlockObject.Create(FBlock.Replicate);
  result := o;
end;

function TMemoryBlockObject.Size: integer;
begin
  result := FBlock.Data.Size;
end;


end.
