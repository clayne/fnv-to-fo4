unit __FNVMultiLoop2;

///  Creates List per Signature

interface
implementation
uses xEditAPI, __FNVMultiLoopFunctions, Classes, SysUtils, StrUtils, Windows; //Remove before use in xEdit

var
NPCList, 
NPCListprev, 
slWRLD,
slCELL,
slREFR,
slACHR,
slACRE,
slLAND,
slNAVM,
slDIAL, 
slINFO, 
slfilelist: TStringList;

k: integer;

rec: IInterface;

nameslWRLD,
nameslCELL,
nameslREFR,
nameslACHR,
nameslACRE,
nameslLAND,
nameslNAVM,
nameslDIAL, 
nameslINFO, 
loadordername, 
grupname: String;

{ Not Used
function filerename(filename, grupname: String; j: integer): String;
var
j: integer;
begin
	if FileExists(filename) then
	begin
		//filename:= (copy(filename, 1, LastDelimiter('_', filename)) + IntToStr(1 + StrToInt(copy(filename, (LastDelimiter('_', filename) + 1), (LastDelimiter('.csv', filename) - LastDelimiter('_', filename) - 1))));
		j := j + 1;
		filename := (ProgramPath + 'data\' + GetFileName(rec) + '_' + grupname + '_' + IntToStr(j) + '.csv');
		AddMessage(filename);
		filename := filerename(filename, grupname, j);
		Result := filename;
	end;
	//else Result := filename;
end;
}

procedure MergeStrings(Dest, Source: TStrings) ; //order is wrong works
var j : integer;
begin
   for j := 0 to -1 + Source.Count do
     if Dest.IndexOf(Source[j]) = -1 then
       Dest.Add(Source[j]) ;
end;

procedure finalsavelist(finalfilenametosave: String; slListToSave: TStringList);
begin
		AddMessage('Saving list to ' + finalfilenametosave);
		if not FileExists(finalfilenametosave) then slfilelist.Add(stringreplace(finalfilenametosave, (ProgramPath + 'data\'), '', [rfReplaceAll]));
		slListToSave.SaveToFile(finalfilenametosave);
end;

function getfilenamestring(filename2: String): String;
var
i: integer;
newfilename: String;
begin
	i := 0;
	newfilename := (filename2 + '0.csv');
	while FileExists(newfilename) do
	begin
		i := i + 1;
		newfilename := (filename2 + IntToStr(i) + '.csv');
	end;
	Result := newfilename;
end;


procedure savelist2(rec: IInterface; k: integer; grupname: String);
var
i: integer;
filename, finalfilename: String;
begin
  i := 0;
	filename := (ProgramPath + 'data\' + GetFileName(rec) + '_' + 'LoadOrder_' + IntToHex(GetLoadOrder(GetFile(rec)), 2) + '_' + 'GRUP' + '_' + grupname + '_');
	finalfilename := (filename + '0.csv');
	//filename := filerename(filename, grupname, 0);
	finalfilename := getfilenamestring(filename);
	if grupname = 'DIAL' then
	begin
		if (slDIAL.Count + NPCList.Count) < 5001 then 
		begin
			MergeStrings(slDIAL, NPCList);
			nameslDIAL := filename;
			if ((k = 1) OR (k = 2)) then
			begin
				finalsavelist(finalfilename, slDIAL);
				slDIAL.Clear;
			end;
		end
		else
		begin
			nameslDIAL := filename;
			finalsavelist(getfilenamestring(filename), slDIAL);
			slDIAL.Clear;			
			MergeStrings(slDIAL, NPCList);
		end;		
	end
	else if grupname = 'INFO' then
	begin
		if (slINFO.Count + NPCList.Count) < 5001 then 
		begin
			MergeStrings(slINFO, NPCList);
			nameslINFO := filename;
			if ((k = 1) OR (k = 2)) then
			begin
				finalsavelist(finalfilename, slINFO);
				slINFO.Clear;
			end;
		end
		else
		begin
			nameslINFO := filename;
			finalsavelist(getfilenamestring(filename), slINFO);
			slINFO.Clear;			
			MergeStrings(slINFO, NPCList);
		end;		
	end
	else if grupname = 'WRLD' then
	begin
		if (slWRLD.Count + NPCList.Count) < 5001 then 
		begin
			MergeStrings(slWRLD, NPCList);
			nameslWRLD := filename;
			if ((k = 1) OR (k = 2)) then
			begin
				finalsavelist(finalfilename, slWRLD);
				slWRLD.Clear;
			end;
		end
		else
		begin
			nameslWRLD := filename;
			finalsavelist(getfilenamestring(filename), slWRLD);
			slWRLD.Clear;			
			MergeStrings(slWRLD, NPCList);
		end;		
	end
	else if grupname = 'CELL' then
	begin
		if (slCELL.Count + NPCList.Count) < 5001 then 
		begin
			MergeStrings(slCELL, NPCList);
			nameslCELL := filename;
			if ((k = 1) OR (k = 2)) then
			begin
				finalsavelist(finalfilename, slCELL);
				slCELL.Clear;
			end;
		end
		else
		begin
			nameslCELL := filename;
			finalsavelist(getfilenamestring(filename), slCELL);
			slCELL.Clear;			
			MergeStrings(slCELL, NPCList);
		end;		
	end
	else if grupname = 'REFR' then
	begin
		if (slREFR.Count + NPCList.Count) < 5001 then 
		begin
			MergeStrings(slREFR, NPCList);
			nameslREFR := filename;
			if ((k = 1) OR (k = 2)) then
			begin
				finalsavelist(finalfilename, slREFR);
				slREFR.Clear;
			end;
		end
		else
		begin
			nameslREFR := filename;
			finalsavelist(getfilenamestring(filename), slREFR);
			slREFR.Clear;			
			MergeStrings(slREFR, NPCList);
		end;		
	end
	else if grupname = 'ACHR' then
	begin
		if (slACHR.Count + NPCList.Count) < 5001 then 
		begin
			MergeStrings(slACHR, NPCList);
			nameslACHR := filename;
			if ((k = 1) OR (k = 2)) then
			begin
				finalsavelist(finalfilename, slACHR);
				slACHR.Clear;
			end;
		end
		else
		begin
			nameslACHR := filename;
			finalsavelist(getfilenamestring(filename), slACHR);
			slACHR.Clear;			
			MergeStrings(slACHR, NPCList);
		end;		
	end
	else if grupname = 'ACRE' then
	begin
		if (slACRE.Count + NPCList.Count) < 5001 then 
		begin
			MergeStrings(slACRE, NPCList);
			nameslACRE := filename;
			if ((k = 1) OR (k = 2)) then
			begin
				finalsavelist(finalfilename, slACRE);
				slACRE.Clear;
			end;
		end
		else
		begin
			nameslACRE := filename;
			finalsavelist(getfilenamestring(filename), slACRE);
			slACRE.Clear;			
			MergeStrings(slACRE, NPCList);
		end;		
	end
	else if grupname = 'LAND' then
	begin
		if (slLAND.Count + NPCList.Count) < 5001 then 
		begin
			MergeStrings(slLAND, NPCList);
			nameslLAND := filename;
			if ((k = 1) OR (k = 2)) then
			begin
				finalsavelist(finalfilename, slLAND);
				slLAND.Clear;
			end;
		end
		else
		begin
			nameslLAND := filename;
			finalsavelist(getfilenamestring(filename), slLAND);
			slLAND.Clear;			
			MergeStrings(slLAND, NPCList);
		end;		
	end
	else if grupname = 'NAVM' then
	begin
		if (slNAVM.Count + NPCList.Count) < 5001 then 
		begin
			MergeStrings(slNAVM, NPCList);
			nameslNAVM := filename;
			if ((k = 1) OR (k = 2)) then
			begin
				finalsavelist(finalfilename, slNAVM);
				slNAVM.Clear;
			end;
		end
		else
		begin
			nameslNAVM := filename;
			finalsavelist(getfilenamestring(filename), slNAVM);
			slNAVM.Clear;			
			MergeStrings(slNAVM, NPCList);
		end;		
	end
	else
	begin
		if FileExists(filename + IntToStr(i - 1) + '.csv') then 
		begin
			NPCListprev.LoadFromFile(filename + IntToStr(i - 1) + '.csv');
			if (NPCListprev.Count + NPCList.Count) < 5001 then
			begin
				MergeStrings(NPCList, NPCListprev);
				finalfilename := (filename + IntToStr(i - 1) + '.csv');
			end;
		end;
		finalsavelist(finalfilename, NPCList);
	end;
	if ((k = 1) OR (k = 2)) then begin
		if slDIAL.Count > 0 then finalsavelist(getfilenamestring(nameslDIAL), slDIAL);
		slDIAL.Clear;
		if slINFO.Count > 0 then finalsavelist(getfilenamestring(nameslINFO), slINFO);
		slINFO.Clear;
		if slWRLD.Count > 0 then finalsavelist(getfilenamestring(nameslWRLD), slWRLD);
		slWRLD.Clear;
		if slCELL.Count > 0 then finalsavelist(getfilenamestring(nameslCELL), slCELL);
		slCELL.Clear;
		if slREFR.Count > 0 then finalsavelist(getfilenamestring(nameslREFR), slREFR);
		slREFR.Clear;
		if slACHR.Count > 0 then finalsavelist(getfilenamestring(nameslACHR), slACHR);
		slACHR.Clear;
		if slACRE.Count > 0 then finalsavelist(getfilenamestring(nameslACRE), slACRE);
		slACRE.Clear;
		if slLAND.Count > 0 then finalsavelist(getfilenamestring(nameslLAND), slLAND);
		slLAND.Clear;
		if slNAVM.Count > 0 then finalsavelist(getfilenamestring(nameslNAVM), slNAVM);
		slNAVM.Clear;
	end;
		NPCList.Clear;
		NPCListprev.Clear;
end;

//Recursive(e, true);
function Initialize: integer;
begin
	NPCList := TStringList.Create;
	NPCListprev := TStringList.Create;
	slWRLD := TStringList.Create;
	slCELL := TStringList.Create;
	slREFR := TStringList.Create;
	slACHR := TStringList.Create;
	slACRE := TStringList.Create;
	slLAND := TStringList.Create;
	slNAVM := TStringList.Create;
	slDIAL := TStringList.Create;
	slINFO := TStringList.Create;
	slfilelist := TStringList.Create;
	k := 1;
  Result := 0;
end;
	
function Process(e: IInterface): integer;
var
slstring: String;
begin
	// Compare to previous record
	if (Assigned(rec) AND (Signature(e) <> grupname) AND (NPCList.Count > 0)) then savelist2(rec, 0, grupname);
	if (Assigned(rec) AND (loadordername <> GetFileName(e))) then 
	begin
		AddMessage('Went To Different File');
		if NPCList.Count > 0 then savelist2(rec, 1, grupname);
		rec := Nil;
		loadordername := GetFileName(e);
	end;
	// Compare to previous record
	slstring := (IntToStr(GetLoadOrderFormID(e)) + ';' + IntToStr(ReferencedByCount(e)) + ';' + FullPath(e));
	rec := e;
	loadordername := GetFileName(rec);
	grupname := Signature(rec);
	if Signature(e) <> 'NAVI' then NPCList.Add(Recursive2(e, slstring)) else
	begin
		NPCList.Add(IntToStr(GetLoadOrderFormID(e)));
		NPCList.Add(IntToStr(ReferencedByCount(e)));
		NPCList.Add(FullPath(e));
		AddMessage('Yes');
		RecursiveNAVI(e, NPCList);
		savelist2(rec, 0, grupname);
	end;
	if NPCList.Count > 4999 then savelist2(rec, 0, grupname);
  Result := 0;
end;

function Finalize: integer;
begin
	AddMessage('Finalizing......');
	if NPCList.Count > 0 then savelist2(rec, 2, grupname);
	NPCList.Free;
	//NPCListprev.Free;
	slfilelist.SaveToFile(ProgramPath + 'data\' + '_filelist.csv');
	slfilelist.Free;
	rec := Nil;
  Result := 0;
end;

end.