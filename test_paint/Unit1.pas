unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, Menus,
  uUndoData, uMemoryBlock, uBinaryTree;   // undo unit

// custom undo data class
const
  _CellWidth = 128;
  _CellHeight = 128;

type
  TBitmapUndoObject=class(TSingleUndoObjectBase)
    protected
      fpool : TMemoryBlockPool;
    public
      canvaswidth,canvasheight : integer;
      cellcount : integer;
      data : array of TMemoryBlockData;  // array of TMemoryStream

      constructor Create(pool:TMemoryBlockPool);
      destructor  Destroy; override;
      function    Compare(other:TSingleUndoObjectBase):boolean; override;      // compare self and other
      function    Replicate:TSingleUndoObjectBase; override;                   // replicate(duplicate) self class
  end;

type
  TBitmapCell=class
    protected
      fpool : TMemoryBlockPool;
      fchangeflag : boolean;
      ftempbuffer : TMemoryStream;
    public
      offsetx,offsety : integer;
      surface : TBitmap;
      data : TMemoryBlockData;

      constructor Create(pool:TMemoryBlockPool);
      destructor  Destroy; override;
      procedure   MemoryImage;
      procedure   RestoreImage(ms:TMemoryStream);

      procedure   PaintFill(col:integer);
      procedure   PaintBrush(x,y , size,col:integer);
  end;
type
  TForm1 = class(TForm)
    PreviewBox: TPaintBox;
    HelpMemo: TMemo;
    MainMenu1: TMainMenu;
    EditMenuItem: TMenuItem;
    UndoMenuItem: TMenuItem;
    RedoMenuItem: TMenuItem;
    N1: TMenuItem;
    ClearMenuItem: TMenuItem;
    LogMemo: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure PreviewBoxPaint(Sender: TObject);
    procedure PreviewBoxMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure PreviewBoxMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure PreviewBoxMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure ClearMenuItemClick(Sender: TObject);
    procedure RedoMenuItemClick(Sender: TObject);
    procedure UndoMenuItemClick(Sender: TObject);
  private
    { Private 宣言 }
    fpool : TMemoryBlockPool;
    fundo : TSingleUndo;

    fcanvaswidth,fcanvasheight : integer;
    fcellcount : integer;
    fcells : array of TBitmapCell;

    fbuffer : TBitmap;    // preview dublebuffer surface

    foffsetx,foffsety : integer;   // view offset position
    fmousedown : boolean;          // mouse button event flag
    fmousex,fmousey : integer;
  public
    { Public 宣言 }

    procedure CellInit;
    procedure CellSetup(w,h:integer);
    procedure CellDraw;
    procedure CellRestore(d:TBitmapUndoObject);

    procedure UndoAdd;
    procedure Undo;
    procedure Redo;

    procedure PoolLogRefresh;
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

{ TBitmapUndoObject }

function TBitmapUndoObject.Compare(other: TSingleUndoObjectBase): boolean;
var
  o1,o2 : TBitmapUndoObject;
  n,i : integer;
begin
  o1 := self;
  o2 := TBitmapUndoObject(other);

  result := false;
  if o1.canvaswidth <> o2.canvaswidth then exit;
  if o1.canvasheight <> o2.canvasheight then exit;
  if  o1.cellcount <> o2.cellcount then exit;

  // memory block compare
  n := o1.cellcount;
  for i:=0 to n-1 do
    if pointer(o1.data[i]) <> pointer(o2.data[i]) then exit;

  result := true;
end;

constructor TBitmapUndoObject.Create(pool:TMemoryBlockPool);
begin
  fpool := pool;
end;

destructor TBitmapUndoObject.Destroy;
var
  o : TMemoryBlockData;
begin
  // free memory block data
  for o in data do
    fpool.FreeBlock(o);

  inherited;
end;

function TBitmapUndoObject.Replicate: TSingleUndoObjectBase;
var
  o1,o2 : TBitmapUndoObject;
  i : integer;
begin
  o1 := self;
  o2 := TBitmapUndoObject.Create(fpool);
  // replecate (hard copy)
  o2.canvaswidth := o1.canvaswidth;
  o2.canvasheight := o1.canvasheight;

  // replecate MemoryBlockData class , add class reference counter. very light process :)
  o2.cellcount := o1.cellcount;
  SetLength(o2.data , o2.cellcount);
  for i:=0 to o1.cellcount-1 do
    o2.data[i] := o1.data[i].Replicate;

  result := o2;
end;

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
begin
  fpool := TmemoryBlockPool.Create;   // duplicate memory stream optimize class
  fundo := TSingleUndo.Create;        // undo manager
  fundo.Limit := 8;

  CellSetup(640,480);

  fbuffer := TBitmap.Create;
  fbuffer.HandleType := bmDIB;
  fbuffer.PixelFormat := pf32bit;

  foffsetx := (PreviewBox.Width - fcanvaswidth) div 2;
  foffsety := (PreviewBox.Height - fcanvasheight) div 2;
end;

procedure TForm1.CellInit;
var
  o : TBitmapCell;
begin
  if fcellcount = 0 then exit;

  for o in fcells do
    o.Free;
  fcellcount := 0;
end;

procedure TForm1.CellRestore(d: TBitmapUndoObject);
var
  needresize : boolean;
  i : integer;
begin
  needresize := false;
  if d.canvaswidth <> fcanvaswidth then needresize := true;
  if d.canvasheight <> fcanvasheight then needresize:= true;
  if d.cellcount <> fcellcount then needresize := true;

  if needresize then
  begin
    CellInit;
    CellSetup(d.canvaswidth,d.canvasheight);
  end;

  if fcellcount <> d.cellcount then
  begin
     raise Exception.Create('CellRestore : Error! cell count missmatch!');
    exit;
  end;

  for i:=0 to fcellcount-1 do
  begin
    fcells[i].RestoreImage(d.data[i].Data);
  end
end;

procedure TForm1.Undo;
var
  d : TBitmapUndoObject;
begin
  if fundo.IsUndoEmpty then exit;

  d := TBitmapUndoObject(fundo.Undo);  // return reference. do not need free.
  Cellrestore(d);   // restore cells

  CellDraw;
  PoolLogRefresh;
end;

procedure TForm1.UndoAdd;
var
  o : TBitmapCell;
  d : TBitmapUndoObject;
  i : integer;
begin
  // make undo data. changed cells only.
  for o in fcells do
    o.MemoryImage;

  // make undo object
  d := TBitmapUndoObject.Create(fpool);
  d.canvaswidth := fcanvaswidth;
  d.canvasheight := fcanvasheight;

  d.cellcount := fcellcount;
  Setlength(d.data , fcellcount);
  for i:=0 to fcellcount-1 do
    d.data[i] := fcells[i].data.Replicate;   // add refernce count. very light.

  // add undo
  fundo.Add(d);

  d.Free;
end;

procedure TForm1.UndoMenuItemClick(Sender: TObject);
begin
  Undo;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  CellInit;

  fbuffer.Free;
  fundo.Free;
  fpool.free;
end;

procedure TForm1.PoolLogRefresh;
var
  list : TList;
  p : pointer;
  o : TMemoryBlockData;
  usage : integer;
begin
  LogMemo.Clear;
  LogMemo.Lines.Add('memory block pool list');

  usage := 0;

  list := fpool.GetBlockList;
  for p in list do
  begin
    o := TMemoryBlockData(p);
    LogMemo.Lines.Add(format('block(%x)ref:%d',[cardinal(o),o.Reference]));
    usage := usage + o.Data.Size;
  end;

  LogMemo.Lines.Add(format('usage memory : %dkb',[usage div 1024]));
  LogMemo.Lines.Add(format('absolute memory : %dkb',[(_CellWidth*_CellHeight*4*fcellcount*fundo.Count) div 1024]));
end;

procedure TForm1.PreviewBoxMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  fmousedown := true;
  fmousex := X;
  fmousey := Y;

  // brush
  if Button = mbLeft then
  begin
    PreviewBoxMouseMove(sender,[ssLeft],X,Y);  // brush call
  end;
end;

procedure TForm1.PreviewBoxMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  diffx,diffy : integer;
  col,size : integer;
  o : TBitmapCell;
begin
  if not(fmousedown) then exit;

  diffx := X - fmousex;
  diffy := Y - fmousey;

  // view offset
  if Shift = [ssRight] then
  begin
    foffsetx := foffsetx + diffx;
    foffsety := foffsety + diffy;
    CellDraw;
  end;

  // brush
  if Shift = [ssLeft] then
  begin
    col := random($ffffff);
    size := 10 + random(10);
    for o in fcells do
      o.PaintBrush(X-foffsetx,Y-foffsety , size,col);
    CellDraw;
  end;

  fmousex := X;
  fmousey := Y;
end;

procedure TForm1.PreviewBoxMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  fmousedown := false;

  // make undo data & add undo
  UndoAdd;
  // memory block log
  PoolLogRefresh;
end;

procedure TForm1.PreviewBoxPaint(Sender: TObject);
begin
  if fcellcount = 0 then exit;

  CellDraw;
end;

procedure TForm1.Redo;
var
  d : TBitmapUndoObject;
begin
  if fundo.IsRedoEmpty then exit;

  d := TBitmapUndoObject(fundo.Redo);  // return reference. do not need free.
  CellRestore(d);   // restore cells

  CellDraw;
  PoolLogRefresh;
end;

procedure TForm1.RedoMenuItemClick(Sender: TObject);
begin
  Redo;
end;

procedure TForm1.CellDraw;
var
  o : TBitmapCell;
  x,y : integer;
begin
  // preview size
  if (PreviewBox.Width <> fbuffer.Width) or (PreviewBox.Height <> fbuffer.Height) then
    fbuffer.SetSize(PreviewBox.Width,PreviewBox.Height);

  // draw cells image
  with fbuffer.Canvas do
  begin
    // back ground
    brush.Style := bsSolid;
    brush.Color := $444444;
    fillrect(rect(0,0 , fbuffer.Width,fbuffer.Height));
    // cell
    for o in fcells do
    begin
      // view offset + cell.offset
      x := foffsetx + o.offsetx;
      y := foffsety + o.offsety;
      // draw
      Bitblt(
        fbuffer.Canvas.Handle , x,y , _CellWidth,_CellHeight ,
        o.surface.Canvas.Handle , 0,0,
        SRCCOPY
      );
    end;
  end;

  // flip primary
  Bitblt(
    PreviewBox.Canvas.Handle , 0,0,fbuffer.Width,fbuffer.Height,
    fbuffer.Canvas.Handle, 0,0,
    SRCCOPY
  );
end;

procedure TForm1.CellSetup(w,h: integer);
var
  cw,ch : integer;
  i : integer;
  o : TBitmapCell;
begin
  CellInit;

  cw := (w + (_CellWidth-1)) div _CellWidth;
  ch := (h + (_CellHeight-1)) div _CellHeight;
  fcellcount := cw*ch;

  fcanvaswidth := w;
  fcanvasheight := h;

  SetLength(fcells,fcellcount);
  for i:=0 to fcellcount-1 do
  begin
    o := TBitmapCell.Create(fpool);
    o.offsetx := (i mod cw) * _CellWidth;   // cell position offset
    o.offsety := (i div cw) * _CellHeight;
    fcells[i] := o;
  end;
end;

procedure TForm1.ClearMenuItemClick(Sender: TObject);
var
  o : TBitmapCell;
begin
  for o in fcells do
    o.PaintFill($000000);

  // init undo
  fundo.Clear;
  // make undo data & add undo
  UndoAdd;

  CellDraw;
  PoolLogRefresh;
end;

{ TBitmapCell }

constructor TBitmapCell.Create(pool:TMemoryBlockPool);
begin
  fpool := pool;
  fchangeflag := false;    // paint event flag
  data := nil;

  // canvas bitmap
  surface := TBitmap.Create;
  surface.HandleType := bmDIB;
  surface.PixelFormat := pf32Bit;
  surface.SetSize(_CellWidth,_CellHeight);

  // temporary serialize data buffer
  ftempbuffer := TMemoryStream.Create;
  ftempbuffer.SetSize(_CellWidth*_CellHeight*4);   // 32bit

  // fill
  PaintFill($000000);

  // make undo data
  MemoryImage;
end;

destructor TBitmapCell.Destroy;
begin
  if data <> nil then fpool.FreeBlock(data);

  surface.Free;
  ftempbuffer.Free;

  inherited;
end;

procedure TBitmapCell.MemoryImage;
var
  dptr,sptr : ^cardinal;
  i,j : integer;
begin
  // change flag
  if not(fchangeflag) then exit;

  if data <> nil then fpool.FreeBlock(data);

  // make serialize data (pixel data)
  // fixed size (_CellWidth * _Cellheight)
  dptr := ftempbuffer.Memory;
  for i:=0 to _CellHeight-1 do
  begin
    sptr := surface.ScanLine[i];
    for j:=0 to _CellWidth-1 do
    begin
      dptr^ := sptr^;
      inc(dptr);
      inc(sptr);
    end;
  end;

  // get optimize memory data
  data := fpool.GetBlock(ftempbuffer);

  // change flag
  fchangeflag := false;
end;

procedure TBitmapCell.PaintBrush(x,y , size,col:integer);
var
  rr : integer;
begin
  // area check
  if x < offsetx - size then exit;
  if x > offsetx + _CellWidth + size then exit;
  if y < offsety - size then exit;
  if y > offsety + _CellHeight + size then exit;

  rr := size div 2;
  with surface.Canvas do
  begin
    brush.Color := col;
    brush.Style := bsSolid;
    pen.Color := col;
    pen.Style := psSolid;
    x := x - offsetx;
    y := y - offsety;
    surface.Canvas.Ellipse(x-rr,y-rr,x+rr,y+rr);
  end;

  fchangeflag := true;
end;

procedure TBitmapCell.PaintFill(col: integer);
begin
  surface.Canvas.Brush.Color := col and $ffffff;
  surface.Canvas.FillRect(rect(0,0,_CellWidth,_CellHeight));

  fchangeflag := true;
end;

procedure TBitmapCell.RestoreImage(ms: TMemoryStream);
var
  dptr,sptr : ^cardinal;
  i,j : integer;
begin
  // make serialize data (pixel data)
  // fixed size (_CellWidth * _Cellheight)
  if ms.Size <> _CellWidth*_CellHeight*4 then exit;

  sptr := ms.Memory;
  for i:=0 to _CellHeight-1 do
  begin
    dptr := surface.ScanLine[i];
    for j:=0 to _CellWidth-1 do
    begin
      dptr^ := sptr^;
      inc(dptr);
      inc(sptr);
    end;
  end;

  fchangeflag := true;

  // refresh undo data
  MemoryImage;
end;

end.
