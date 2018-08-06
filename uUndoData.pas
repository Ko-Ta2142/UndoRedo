unit uUndoData;

interface

uses SysUtils,Classes,StrUtils,math,contnrs;

// single data
// small data undo class. simple & speedy. use large memory.
type
  TSingleUndoObjectBase=class
    public
      // constructor Create;
      // destructor Destroy; override;
      function    Compare(obj:TSingleUndoObjectBase):boolean; virtual; abstract;   // compare self and other
      function    Replicate:TSingleUndoObjectBase; virtual; abstract;              // replicate(duplicate) self class
  end;
  TSingleUndo=class
    private
      function    GetCount: integer; inline;
      function    GetCurrentData: TSingleUndoObjectBase;
      function    GetData(n:integer): TSingleUndoObjectBase;
    protected
      FLimit : integer;
      FIndex : integer;
      FUndoData : TObjectList;
    public
      constructor Create;
      destructor  Destroy; override;
      procedure   Init;
      procedure   Clear;
      // state
      function    IsUndoEmpty:Boolean; inline;
      function    IsRedoEmpty:Boolean; inline;
      // undo redo
      function    Add(const o:TSingleUndoObjectBase; replicate:boolean=true):Boolean;
      function    Undo:TSingleUndoObjectBase;
      function    Redo:TSingleUndoObjectBase;
      // property
      property    Current:TSingleUndoObjectBase read GetCurrentData;
      property    Limit:integer read FLimit write FLimit;
      property    Count : integer read GetCount;
      property    _Index : integer read FIndex;
      property    Data[n:integer] : TSingleUndoObjectBase read GetData;
  end;

// TMemoryStream template
type
  TSingleUndoObjectMemoryStream=class(TSingleUndoObjectBase)
    public
      data : TMemoryStream;

      constructor Create;
      destructor  Destroy; override;
      function    Compare(other:TSingleUndoObjectBase):boolean; override;      // compare self and other
      function    Replicate:TSingleUndoObjectBase; override;                   // replicate(duplicate) self class
  end;

// how to use

// Serialize the data to TSingleUndoObjectBase and use it as Undo data.
// TSingleUndoObjectBaseにシリアライズされたものを、undoデータとして使用します。
// If TSingleUndoObjectMemoryStream is used, TMemoryStream can be used as serialized data.
// TSingleUndoObjectMemoryStreamを使えば、TMemoryStreamをシリアライズデータの置き場所として使用出来ます。

// TSingle? Is where TMulti?
// No. TMulti(Array data) can be realized by create TSingleUndoObjectBase sub class.
// TMultiUndoは存在しません。配列データを取り扱うundoはTSingleUndoObjectBaseを派生させて作ります。

// - push undo (difference check exists)
// - undoに追加。変化が無ければ追加を中止します。適当にぶち込んでOKです。

// o := TSingleUndoObjectMemoryStream(TSingleUndoObjectBase custom class).create;
// o.data.CopyFrom( user undo binary data );   // set undo data
// if SingleUndo.Add(o) then ShowMessage('add undo.')
//                      else ShowMessage('no change data. not need it.');
// o.free;   // need free (default replicate undo object)

// - pop undo
// - 1つ後方のデータを取得します。参照を取得するので解放しないこと。

// if SingleUndo.IsUndoEmpty then exit;
// o := SingleUndo.Undo;
// user restore function(o.data);
// //o.free;   // do not free object!

// - pop redo
// - 1つ前方のデータを取得します。参照を取得するので解放しないこと。

// if SingleUndo.IsRedoEmpty then exit;
// o := SingleUndo.Redo;
// user restore function(o.data);
// //o.free;   // do not free object!


implementation

{ TSingleUndo }

function TSingleUndo.Add(const o:TSingleUndoObjectBase; replicate:boolean): Boolean;
  function inCompare(ms1,ms2:TMemoryStream):Boolean;
  var
    n1,n2 : Integer;
  begin
    result := false;
    n1 := ms1.Size;
    n2 := ms2.Size;
    if (n1<>n2)then exit;

    result := CompareMem(ms1.Memory,ms2.Memory,n1);
  end;
var
  t : TSingleUndoObjectBase;
begin
  result := false;

  // compare
  if Current <> nil then
  begin
    if o.Compare(current) then exit;
  end;

  // delete redo
  while FUndoData.Count > FIndex+1 do
  begin
    FUndoData.Delete(FUndoData.Count-1);
  end;

  // duplicate
  if replicate then t := o.Replicate
               else t := o;

  // add
  FUndoData.Add(t);
  inc(FIndex);
  if FIndex > FUndoData.Count-1 then FIndex := FUndoData.Count-1;

  // limit
  while FUndoData.Count > FLimit do
  begin
    dec(FIndex);
    FUndoData.Delete(0);
  end;

  result := true;
end;

procedure TSingleUndo.Clear;
begin
  Init;
end;

constructor TSingleUndo.Create;
begin
  FLimit := 64;
  FUndoData := TObjectList.Create;
  Init;
end;

destructor TSingleUndo.Destroy;
begin
  Init;
  FUndoData.Free;

  inherited;
end;

function TSingleUndo.GetCount: integer;
begin
  result := FUndoData.Count;
end;

function TSingleUndo.GetCurrentData: TSingleUndoObjectBase;
begin
  result := nil;
  if FUndoData.Count = 0 then exit;
  if FIndex = -1 then exit;

  result := TSingleUndoObjectBase(FUndoData.Items[FIndex]);
end;

function TSingleUndo.GetData(n:integer): TSingleUndoObjectBase;
begin
  result := TSingleUndoObjectBase(FUndoData.Items[n]);
end;

procedure TSingleUndo.Init;
begin
  FUndoData.Clear;
  FIndex := -1;
end;

function TSingleUndo.IsRedoEmpty: Boolean;
begin
  result := FIndex >= FUndoData.Count-1;
end;

function TSingleUndo.IsUndoEmpty: Boolean;
begin
  result := FIndex < 1;
end;

function TSingleUndo.Redo:TSingleUndoObjectBase;
begin
  result := nil;
  if IsRedoEmpty then exit;

  inc(FIndex);
  result := current;
end;

function TSingleUndo.Undo:TSingleUndoObjectBase;
begin
  result := nil;
  if IsUndoEmpty then exit;

  if FIndex > 0 then dec(FIndex);
  result := Current;
end;

{ TSingleUndoObjectMemoryStream }

function TSingleUndoObjectMemoryStream.Compare(other : TSingleUndoObjectBase): boolean;
var
  o1,o2 : TSingleUndoObjectMemoryStream;
begin
  result := false;
  o1 := self;
  o2 := TSingleUndoObjectMemoryStream(other);

  if o2.data = nil then exit;
  if o1.data.Size <> o2.data.Size then exit;

  result := CompareMem(o1.data.Memory , o2.data.Memory , o1.data.Size);
end;

constructor TSingleUndoObjectMemoryStream.Create;
begin
  data := TMemoryStream.Create;
end;

destructor TSingleUndoObjectMemoryStream.Destroy;
begin
  data.Free;

  inherited;
end;

function TSingleUndoObjectMemoryStream.Replicate: TSingleUndoObjectBase;
var
  size : integer;
  o : TSingleUndoObjectMemoryStream;
begin
  size := self.data.Size;

  o := TSingleUndoObjectMemoryStream.Create;
  o.data.SetSize(size);
  move(self.data.Memory^ , o.data.Memory^ , size);  // copy

  result := o;
end;

end.
