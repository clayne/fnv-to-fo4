program NifMultiboundPatcher;

{$APPTYPE CONSOLE}

{$R *.res}

//uses
//  System.SysUtils, System.IOUtils, Vcl.Forms, Vcl.Dialogs, System.Classes;

uses
  System.SysUtils,
  System.IOUtils,
  Winapi.Windows,
  Winapi.Messages,
  System.Variants,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs, // Automatically added by IDE
  Vcl.StdCtrls,
  StrUtils,
  Types,
  Masks;


type
  TForm1 = class(TForm)
    Button1: TButton;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
iLastPatternPos: Integer;

//implementation
//
//{$R *.dfm}

function GetFiles2(const Path: String): TStringList;
var
  i     : Integer;
  PathArray : TStringDynArray;

begin
  // Get the current folder
  Result := TStringList.Create;
  Writeln('Project Files in : ' + Path + ' :');
  Writeln;

  // Get all project files in this folder
  PathArray := System.IOUtils.TDirectory.GetFiles(Path, '*.BTR');
  for i := 0 to (Length(PathArray) - 1) do
    Result.Add(PathArray[i]);
end;

function MyGetFiles(const Path, Masks: string): TStringList;
var
  MaskArray, PathArray: TStringDynArray;
  Predicate: TDirectory.TFilterPredicate;
  i: Integer;
  SearchOption: TSearchOption;
begin
  Result := TStringList.Create;
  MaskArray := SplitString(Masks, ';');
  SearchOption := TSearchOption.soAllDirectories;
  Predicate :=
    function(const Path: string; const SearchRec: TSearchRec): Boolean
    var
      Mask: string;
    begin
      for Mask in MaskArray do
        if MatchesMask(SearchRec.Name, Mask) then
          exit(True);
      exit(False);
    end;
  PathArray := TDirectory.GetFiles(Path, Predicate);
  for i := 0 to (Length(PathArray) - 1) do
    Result.Add(PathArray[i]);
end;

function GetLODPaths(const Path: String): TStringList;
var
i: Integer;
PathArray: TStringDynArray;
begin
  Result := TStringList.Create;
  PathArray := TDirectory.GetDirectories(Path);
  for i := 0 to (Length(PathArray) - 1) do
  begin
    Result.AddStrings(MyGetFiles((PathArray[i] + '\'), '*.nif'));
    if DirectoryExists(PathArray[i]+ '\blocks\') then
      Result.AddStrings(MyGetFiles((PathArray[i]+ '\blocks\'), '*nif'));
  end;
end;

function GetWorldSpaces(const Path: String): TStringList;
var
i: Integer;
PathArray: TStringDynArray;
begin
  Result := TStringList.Create;
  PathArray := TDirectory.GetDirectories(Path);
  for i := 0 to (Length(PathArray) - 1) do
    Result.Add(Copy(PathArray[i], (Length(Path) + 1), MaxInt));
end;

function StringToByteArray(const pattern: String): TBytes;
var
  slAOB: TStringList;
  i: Integer;
begin

      slAOB := TStringList.Create;
      slAOB.Delimiter := ' ';
      slAOB.StrictDelimiter := True;
      slAOB.DelimitedText := pattern;
//      for i := 0 to (slAOB.Count - 1) do
//        Writeln(slAOB[i]);
//      SetLength(byteArray, slAOB.Count);
      SetLength(Result, slAOB.Count);
      for i := 0 to (slAOB.Count - 1) do
        Result[i] := StrToInt('$' + slAOB[i]);
//        byteArray[i] := StrToInt('$' + slAOB[i]);
end;

function ReplaceBytePattern(Data: TBytes; OldPattern: TBytes; NewPattern: TBytes; bFirstOnly: Boolean): TBytes;
var
i, j: Integer;
bMatch: Boolean;
begin
//  Move(Data[0], Result[0], MaxInt);
  Result := Data;
  for i := 0 to (Length(Data) - 1) do
  begin
    if OldPattern[0] = Data[i] then
    begin
      bMatch := True;
      for j := i to (Length(OldPattern) - 1 + i) do
      begin
        if OldPattern[j - i] <> Data[j] then bMatch := False;
      end;
      if bMatch then
      begin
        Writeln('Match found at position: ' + IntToStr(i));
//        Insert(Data, NewPattern, i);
//        Delete(Data, (i + Length(NewPattern)), Length(OldPattern));
        SetLength(Result, (Length(Data) + (Length(NewPattern) - Length(OldPattern))));
        Move(Data[0], Result[0], (i + 1));
        Move(NewPattern[0], Result[i], Length(NewPattern));
//        Writeln(IntToStr(Length(Result) - (i + Length(OldPattern))));
//        Writeln(IntToStr(Length(Data) - i - Length(NewPattern)));
        Move(Data[i + Length(OldPattern)], Result[i + Length(NewPattern)], (Length(Data) - i - Length(OldPattern)));
        iLastPatternPos := i;
        if bFirstOnly then Break;
//        Move(NewPattern[0], Data[i], Length(NewPattern));
//        Move(Data[i], (Data[i + (Length(NewPattern) - Length(OldPattern))]), (Length(Data) - i + (Length(NewPattern) - Length(OldPattern))))
//        for j := i to (Length(NewPattern) - 1 + i) do
//        begin
//          if (j - i) > Length(OldPattern) then
//          Data[j] := NewPattern[j - i];
//        end;
//        Result := Data;
      end;
    end;
  end;
end;

var
//Dllx: TBytes;
Data:ARRAY [0..27] OF Byte = ($00,$43,$00,$3A,$00,$5C,$00,$4D,$00,$53,$00,$31,$00,$30,$00,$30,$00,$34,$00,$36,$00,$2E,$00,$64,$00,$6C,$00,$6C);
Pattern:ARRAY [0..1] OF Byte = ($00,$30);
b, baSource, bytePattern, newbytePattern: TBytes;
i, j : integer;
bConvert: Boolean;

pBSMultiBoundNode,
pBSMultiBoundOBB,
pBSMulitBoundAABB,
pMultiBoundData,
pNameLand,
pNameLandCorrected,
pChunkDataOld,
pChunkDataNew,
PathRootSource,
PathRootDest,
PathSource,
PathDest,
sourceFile,
sBytes,
filename,
s,
fileType: String;

slFiles, slSourceFiles, slWorldSpaces, slDel: TStringList;
iMultiBoundDataPos: Integer;
openDialog : topendialog;
self: TComponent;
//byteArray  : array of Byte;

begin
  try
    begin

      slFiles := TStringList.Create;
      slSourceFiles := TStringList.Create;
      slWorldSpaces := TStringList.Create;
      bConvert := False;

      case MessageDlg('Process Source?', mtConfirmation, [mbOK, mbCancel], 0) of
        mrOk:
          begin
          // Write code here for pressing button OK
            bConvert := True;
          end;
        mrCancel:
          begin
          // Write code here for pressing button Cancel
            begin
              // Create the open dialog object - assign to our open dialog variable
              openDialog := TOpenDialog.Create(self);

              // Set up the starting directory to be the current one
              openDialog.InitialDir := GetCurrentDir;

              // Allow multiple files to be selected - of any type
              openDialog.Options := [ofAllowMultiSelect];

              // Display the open file dialog
              if not openDialog.Execute
              then ShowMessage('Open file was cancelled')
              else
              begin
                // Display the selected file names
                for i := 0 to openDialog.Files.Count-1 do
                  ShowMessage(openDialog.Files[i]);
              end;

              if openDialog.Files.Count > 0 then
                slFiles.AddStrings(openDialog.Files);
              // Free up the dialog
              openDialog.Free;
            end;
            bConvert := False;
          end;
      end;

      { TODO -oUser -cConsole Main : Insert code here }
      if bConvert then
      begin
        PathRootSource := 'D:\Games\Fallout New Vegas\FNVExtracted\Data\';
        PathSource := PathRootSource + 'meshes\landscape\lod\';
        PathRootDest := 'D:\Games\Fallout New Vegas\FNVFo4 Converted\Data\';
        slSourceFiles.LoadFromFile(PathRootDest + 'Meshes\Terrain\LODList.csv');
        slDel := TStringList.Create;
        slDel.Delimiter := ';';
        slDel.StrictDelimiter := True;

        Readln;
        for i := 0 to (slSourceFiles.Count - 1) do
        begin
          slDel.DelimitedText := slSourceFiles[i];
          if slDel.Count = 2 then
          begin
            slSourceFiles[i] := slDel[0];
            slFiles.Add(slDel[1]);
          end;
        end;
//        slSourceFiles := GetLODPaths(PathSource);
//        slWorldSpaces := GetWorldSpaces(PathSource);
////        slFiles := MyGetFiles(PathSource, '*.BTR;*.BTO');
//        for i := 0 to (slWorldSpaces.Count - 1) do
//          Writeln(slWorldSpaces[i]);
//        for i := 0 to (slSourceFiles.Count - 1) do
//          Writeln(slSourceFiles[i]);
////        Writeln(PathSource);
      end
      else
      begin
        PathRootSource := '';
        PathDest := 'C:\Temp\Bytes';
      end;

      pNameLand := '4C 61 6E 64 3A 30';
      pNameLandCorrected := '4C 61 6E 64';
      pBSMultiBoundNode := '42 53 4D 75 6C 74 69 42 6F 75 6E 64 4E 6F 64 65';
      pBSMultiBoundOBB := '0F 00 00 00 42 53 4D 75 6C 74 69 42 6F 75 6E 64 4F 42 42 00 00 01 00 02 00 03 00 04 00 05 00';
      pBSMulitBoundAABB := '10 00 00 00 42 53 4D 75 6C 74 69 42 6F 75 6E 64 41 41 42 42 00 00 01 00 02 00 03 00 04 00 05 00';
      pMultiBoundData :=
           '00 00 00 46' // Pos X
        + ' 00 00 00 46' // Pos Y
        + ' 00 80 BF 44' // Pos Z
        + ' 00 00 00 46' // Extent X
        + ' 00 00 00 46' // Extent Y
        + ' 00 00 05 44' // Extent Z
        + ' 01 00 00 00' //
        + ' 00 00 00 00' // All values Little Endian
      ;
      pChunkDataOld := '3C 00 00 00 04 00 00 00 57';
      pChunkDataNew := '18 00 00 00 04 00 00 00 57';

      for i := 0 to (slFiles.Count - 1) do
      begin
        filename := slFiles[i];
        if filename <> '' then
        begin
          Writeln('Processing ' + filename);
          fileType := Copy(filename, (Length(filename) - 3), 4);

          b := TFile.ReadAllBytes(filename);

          bytePattern := StringToByteArray(pBSMultiBoundOBB);
          newbytePattern := StringToByteArray(pBSMulitBoundAABB);
          b := ReplaceBytePattern(b, bytePattern, newbytePattern, True);

          if fileType = '.BTR' then
          begin
            newbytePattern := [$18];
            Move(newbytePattern[0], b[iLastPatternPos + $34], Length(newbytePattern));
            newbytePattern := [$04];
            Move(newbytePattern[0], b[iLastPatternPos + $49], Length(newbytePattern));

            bytePattern := StringToByteArray(pNameLand);
            newbytePattern := StringToByteArray(pNameLandCorrected);

            // Access violation sometimes
//            Writeln('HERE');
            b := ReplaceBytePattern(b, bytePattern, newbytePattern, True);
//            Readln;

            bytePattern := StringToByteArray(pChunkDataOld);
            newbytePattern := StringToByteArray(pChunkDataNew);
            b := ReplaceBytePattern(b, bytePattern, newbytePattern, True);
          end
          else
          begin
            // .BTO
            newbytePattern := [$18];
            Move(newbytePattern[0], b[iLastPatternPos + $3A], Length(newbytePattern));

            newbytePattern := [$03];
            Move(newbytePattern[0], b[iLastPatternPos + $3E], Length(newbytePattern));

            newbytePattern := [$03];
            Move(newbytePattern[0], b[iLastPatternPos + $42], Length(newbytePattern));

//            newbytePattern := [$03];
//            Move(newbytePattern[0], b[iLastPatternPos + $51], Length(newbytePattern));
            Writeln('pos = ' + IntToStr(iLastPatternPos + $51));

            sBytes := '0D 00 00 00 46 61 64 65 4E 6F 64 65 20 41 6E 69 6D 05 00 00 00 6F 62 6A 3A 30 00 00 00 00';
            bytePattern := StringToByteArray(sBytes);
            sBytes := '00 00 00 00 02 00 00 00 3A 32';
            newbytePattern := StringToByteArray(sBytes);
            b := ReplaceBytePattern(b, bytePattern, newbytePattern, True);

            sBytes := '0F 41 0F 42 0F 42 0F 41 0F 43 0F 44 0F 45 0F 46 0F 46 0F 45 0F 47 0F 48 0F 49 0F 4A 0F 4A 0F 49 0F 4B 0F 4C 0F 4D 0F 4E 0F 4E 0F 4D 0F 4F 0F 50 0F 51 0F 52 0F 52 0F 51 0F 53 0F 00 00 00 00 03';
            bytePattern := StringToByteArray(sBytes);
            sBytes := '0F 41 0F 42 0F 42 0F 41 0F 43 0F 44 0F 45 0F 46 0F 46 0F 45 0F 47 0F 48 0F 49 0F 4A 0F 4A 0F 49 0F 4B 0F 4C 0F 4D 0F 4E 0F 4E 0F 4D 0F 4F 0F 50 0F 51 0F 52 0F 52 0F 51 0F 53 0F 00 00 00 00 01';
            newbytePattern := StringToByteArray(sBytes);
            b := ReplaceBytePattern(b, bytePattern, newbytePattern, True);

            sBytes := '3F FF FF FF FF 01 00 00 00 02 00 00 00 05 00 00 00 00 00 00 00 02';
            bytePattern := StringToByteArray(sBytes);
            sBytes := '3F FF FF FF FF 01 00 00 00 02 00 00 00 05 00 00 00 00 00 00 00 00';
            newbytePattern := StringToByteArray(sBytes);
            b := ReplaceBytePattern(b, bytePattern, newbytePattern, True);

//            Delete(b, b[iLastPatternPos + $51], $16);
//            Delete(b, b[350], 22);
//
//            // NiNode "obj" string
//            sBytes := '';
//            bytePattern := StringToByteArray(pNameLand);
//            newbytePattern := StringToByteArray(pNameLandCorrected);
//            b := ReplaceBytePattern(b, bytePattern, newbytePattern, True);
//
//            // BSSubIndexTriShape name
//            sBytes := '';
//            bytePattern := StringToByteArray(pNameLand);
//            newbytePattern := StringToByteArray(pNameLandCorrected);
//            b := ReplaceBytePattern(b, bytePattern, newbytePattern, True);
          end;

          newbytePattern := StringToByteArray(pMultiBoundData);
          if slSourceFiles.Count = slFiles.Count then
          begin
            sourceFile := slSourceFiles[i];
            baSource := TFile.ReadAllBytes(sourceFile);

            // Move Source Multibound data to byte pattern
            Move(baSource[Length(baSource) - Length(newbytePattern)], newbytePattern[0], (Length(newbytePattern)));

            if fileType = '.BTR' then
            begin
//              s := '';
//              for j := 0 to (Length(newbytePattern) - 1) do
//                s := s + ' ' + (IntToHex(newbytePattern[j], 2));
//              Writeln(s);

              // pos x = 8096, pos y = 8096
              sBytes := '00 00 00 46 00 00 00 46';
              bytePattern := StringToByteArray(sBytes);
              Move(bytePattern[0], newbytePattern[0], 8);

              // extent x = 8096, extent y = 8096
              sBytes := '00 00 00 46 00 00 00 46';
              bytePattern := StringToByteArray(sBytes);
              Move(bytePattern[0], newbytePattern[12], 8);
            end;

            PathDest := filename.Insert(Length(PathRootDest), 'PatchedLOD\');
            Writeln(PathDest);
            ForceDirectories(ExtractFilePath(PathDest));
//            readln;
          end;
          iMultiBoundDataPos := (Length(b) - 68);
          if iMultiBoundDataPos > 0 then
          begin
            Writeln(IntToStr(Length(newbytePattern)));
            Writeln(IntToStr(Length(b)));
            Move(newbytePattern[0], b[iMultiBoundDataPos], Length(newbytePattern));
            Delete(b, (iMultiBoundDataPos + Length(newbytePattern)), MaxInt);
            Writeln(IntToStr(Length(b)));
          end;
          if slSourceFiles.Count > 0 then
          begin
            TFile.WriteAllBytes(PathDest, b)
          end
          else
            TFile.WriteAllBytes((PathDest + '_' + IntToStr(i) + '.nif'), b);
          Writeln(PathDest);
        end;
      end;
      Writeln('Done');
      Readln;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
