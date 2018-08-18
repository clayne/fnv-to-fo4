program __FNVImportFuctionsTextv2App;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Windows,
  Winapi.ShellApi,
  System.SysUtils,
  __FNVImportFuctionsTextv2 in '..\Edit Scripts\__FNVImportFuctionsTextv2.pas',
  xEditAPI in '..\xEditAPI.pas',
  __FNVMultiLoop2 in '..\Edit Scripts\__FNVMultiLoop2.pas',
  __FNVMultiLoop in '..\Edit Scripts\__FNVMultiLoop.pas',
  __FNVMultiLoopFunctions in '..\Edit Scripts\__FNVMultiLoopFunctions.pas',
  __TEMPLATE in '..\Edit Scripts\__TEMPLATE.pas',
  __MultidimensionalArrayTest in '..\Edit Scripts\__MultidimensionalArrayTest.pas',
  __FNVMultiLoop3 in '..\Edit Scripts\__FNVMultiLoop3.pas',
  __GetElementType in '..\Edit Scripts\__GetElementType.pas',
  __GetFlagValues in '..\Edit Scripts\__GetFlagValues.pas',
  __TESTLInes in '..\Edit Scripts\__TESTLInes.pas',
  __FNVImportFuctionsTextv2_Functions in '..\Edit Scripts\__FNVImportFuctionsTextv2_Functions.pas',
  __PrintElementPaths in '..\Edit Scripts\__PrintElementPaths.pas',
  __RecursiveReferences in '..\Edit Scripts\__RecursiveReferences.pas',
  __PrintUniqueValue in '..\Edit Scripts\__PrintUniqueValue.pas',
  __PrintElementOccurence in '..\Edit Scripts\__PrintElementOccurence.pas',
  __GetMaterialSwaps in '..\Edit Scripts\__GetMaterialSwaps.pas',
  __AddWorldBlocks in '..\Edit Scripts\__AddWorldBlocks.pas',
  __SetDefaults in '..\Edit Scripts\__SetDefaults.pas',
  __PrintFileReferences in '..\Edit Scripts\__PrintFileReferences.pas',
  __FNVConversionFunctions in '..\Edit Scripts\__FNVConversionFunctions.pas',
  __DeleteInvalidRefrs in '..\Edit Scripts\__DeleteInvalidRefrs.pas',
  __PrintFileReferences2 in '..\Edit Scripts\__PrintFileReferences2.pas';

begin
  try
    ShellExecute(
      0,
      Nil,
      'C:\Users\Terry\OneDrive\xEdit\FO4Edit.exe',
      '-script:"C:\Users\Terry\OneDrive\xEdit\Edit Scripts\__FNVImportFuctionsTextv2.pas" -nobuildrefs',
      'C:\Users\Terry\OneDrive\xEdit',
      SW_SHOWNORMAL
    );
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
