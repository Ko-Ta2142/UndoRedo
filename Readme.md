# simple undo redo & memory compaction 
simple undo redo manage code. and duplicate memory optimize code.\
単純なUndoRedo管理コードと、UndoRedo時に役立つメモリ重複最適化コードです。\
Use there anything other than the editor? :Q \
エディタで以外で使う（役立つ）ことは……たぶんないでしょう。\
about 10KB each , too tiny :)\
だいたいそれぞれ10KBぐらいのとてもちっちゃいコードです。

## sample
sample paint app, be optimizing no-change area data(duplicate serialize data). \
サンプルは、変更がない箇所のデータ（重複した復元用データ）を最適化、ログ出力しています。\
<img src="image01.png">
memory compactioned to about 1/5 in the image.\
画像で約1/5に圧縮、最適化されています。

## etc
そのうちTypeScriptで作るかもしれません。ExtJS(Sencya)使ってみたいので。

## use undo redo
define undoredo data class.\
まずデータ用のクラスを定義。

```delphi
type
  TSingleUndoObjectMemoryStream=class(TSingleUndoObjectBase)
    public
      data : TMemoryStream;

      constructor Create;
      destructor  Destroy; override;
      function    Compare(other:TSingleUndoObjectBase):boolean; override;      // compare self and other
      function    Replicate:TSingleUndoObjectBase; override;                   // replicate(duplicate) self class
  end;
```
create manager , push and pop the data class.\
あとはundoredo管理クラスを生成して、先のデータをプッシュポップするだけ。
```delphi
  undo := TSingleUndo.Create;
  ~~~
  data := TSingleUndoObjectMemoryStream.Create;
  data.data := HogeObject.ReplicateSerializeData;  // replicate MemoryStream
  undo.Add(data); // add,push
  data.Free;
  ~~~
  if not(undo.IsUndoEmpty) then data := undo.Undo; // undo
  if not(undo.IsRedoEmpty) then data := undo.Redo; // undo
  ~~~
  undo.Free
```

## use memory compaction
create pool manager.\
プール（蓄えて管理）するクラスを生成して。
```delphi
  pool := TmemoryBlockPool.Create;
  ~~~
  pool.Free;
```
Get optimize data from MemoryStream(SerializeData).\
メモリデータから重複を最適化されたクラスを取得します。
```delphi
  ms := HogeObject.GetSerializeData; // reference MemoryStream
  block := pool.GetBlock(ms);
```


