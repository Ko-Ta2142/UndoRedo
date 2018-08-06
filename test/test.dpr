program test;

{$APPTYPE CONSOLE}

uses
  //FastMM4,
  SysUtils,
  Classes,
  uUndoData,
  uMemoryBlock;

// custom undo data class
type
  TMemoryBlockUndoData=class(TSingleUndoObjectBase)
    block : TMemoryBlockData;

    destructor  Destroy; override;
    function    Compare(other:TSingleUndoObjectBase):boolean; override;      // compare self and other
    function    Replicate:TSingleUndoObjectBase; override;                   // replicate(duplicate) self class
  end;

// MemoryBlock pool is global.
var
  _pool : TMemoryBlockPool;

// main
procedure main;
  function inMake:TMemoryStream;
  var
    i : integer;
    len : integer;
    sptr : pbyte;
    ms : TMemoryStream;
  begin
    len := 256 + random(32);
    ms := TMemoryStream.Create;
    ms.SetSize(len);
    sptr := ms.Memory;
    for i:=0 to len-1 do
    begin
      sptr^ := i and $ff;
      //sptr^ := random($ff);
      inc(sptr);
    end;
    result := ms;
  end;
var
  undo : TSingleUndo;
  data : TMemoryBlockUndoData;
  ms : TMemoryStream;
  i : integer;
  s : string;
begin
  randomize;

  // create
  _pool := TMemoryBlockPool.Create;
  undo := TSingleUndo.Create;
  undo.Limit := 256;

  for i:=0 to 4096-1 do
  begin
    // generate random memorystream data.
    ms := inMake;
    // make undo data
    data := TMemoryBlockUndoData.Create;
    data.block := _pool.GetBlock(ms);     // optimize duplicate data
    ms.Free;
    writeln('block.add : '+inttostr(integer(data.block))+' : '+inttostr(data.block.Reference));
    // add undo data
    if not(undo.Add(data)) then writeln('no change. pass add.');
    data.Free;
  end;

  // input wait
  readln(s);

  // stack data clear
  undo.Clear;

  // input wait
  readln(s);

  // free
  undo.Free;
  _Pool.Free;
end;

{ TMemoryBlockUndoData }

function TMemoryBlockUndoData.Compare(other: TSingleUndoObjectBase): boolean;
begin
  // do compare class pointer is enough
  result := block = TMemoryBlockUndoData(other).block;
end;

destructor TMemoryBlockUndoData.Destroy;
begin
  writeln('block.delete : '+inttostr(integer(block))+' : '+inttostr(block.Reference));

  _pool.FreeBlock(block);

  inherited;
end;

function TMemoryBlockUndoData.Replicate: TSingleUndoObjectBase;
var
  o : TMemoryBlockUndoData;
begin
  o := TMemoryBlockUndoData.Create;
  o.block := block.Replicate;
  result := o;
end;

// program start
begin
  try
    { TODO -oUser -cConsole Main : ここにコードを記述してください }
    main;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.