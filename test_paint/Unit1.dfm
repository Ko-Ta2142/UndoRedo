object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Paint UndoRedo Sample'
  ClientHeight = 735
  ClientWidth = 1078
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Tahoma'
  Font.Style = []
  Menu = MainMenu1
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 14
  object PreviewBox: TPaintBox
    Left = 0
    Top = 0
    Width = 838
    Height = 646
    Align = alClient
    OnMouseDown = PreviewBoxMouseDown
    OnMouseMove = PreviewBoxMouseMove
    OnMouseUp = PreviewBoxMouseUp
    OnPaint = PreviewBoxPaint
    ExplicitLeft = -6
    ExplicitTop = 8
  end
  object HelpMemo: TMemo
    Left = 0
    Top = 646
    Width = 1078
    Height = 89
    Align = alBottom
    Lines.Strings = (
      'LeftButton : Paint'
      'RightButton : Move view position'
      'ctrl+z : Undo'
      'ctrl+y : Redo')
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 0
  end
  object LogMemo: TMemo
    Left = 838
    Top = 0
    Width = 240
    Height = 646
    Align = alRight
    Lines.Strings = (
      'Log')
    ScrollBars = ssVertical
    TabOrder = 1
  end
  object MainMenu1: TMainMenu
    AutoHotkeys = maManual
    Left = 16
    Top = 32
    object EditMenuItem: TMenuItem
      Caption = 'Edit'
      object UndoMenuItem: TMenuItem
        Caption = 'Undo'
        ShortCut = 16474
        OnClick = UndoMenuItemClick
      end
      object RedoMenuItem: TMenuItem
        Caption = 'Redo'
        ShortCut = 16473
        OnClick = RedoMenuItemClick
      end
      object N1: TMenuItem
        Caption = '-'
      end
      object ClearMenuItem: TMenuItem
        Caption = 'Clear'
        OnClick = ClearMenuItemClick
      end
    end
  end
end
