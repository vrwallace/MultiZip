unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics,
  Dialogs, StdCtrls, dateutils, lcltype, strutils, zipper;

type

  { TForm1 }

  TForm1 = class(TForm)
    ButtonSS: TButton;
    Buttonstart: TButton;
    ButtonStop: TButton;
    Fileswildcardedit: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    recursiveCheckBox: TCheckBox;
    EditSourceDir: TEdit;
    EditStatus: TEdit;
    GroupBox1: TGroupBox;
    GroupBoxSettings: TGroupBox;
    Memo1: TMemo;
    SelectDirectoryDialog1: TSelectDirectoryDialog;
    procedure ButtonStopClick(Sender: TObject);
    procedure ButtonSSClick(Sender: TObject);

    procedure ButtonstartClick(Sender: TObject);
    procedure Memo1Change(Sender: TObject);
    procedure ProcessDir(const SourceDirName: string);
    procedure DumpExceptionCallStack(E: Exception);
    procedure statusstateenable(locked: boolean);
    function passedToHourMinSec(mspassed: integer): string;
  private
    { private declarations }
  public
    { public declarations }
  end;


var
  Form1: TForm1;
  stoppressed: integer = 0;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.ButtonSSClick(Sender: TObject);
begin

  try

    if SelectDirectoryDialog1.Execute then
    begin

      if midstr(selectdirectorydialog1.filename, 2, 2) <> ':\' then
      begin
        ShowMessage('Must be a mapped drive with a drive letter!');
        editsourcedir.Text := '';
      end
      else
        editsourcedir.Text := selectdirectorydialog1.filename;

    end;

  except
    on E: Exception do
      DumpExceptionCallStack(E);
  end;
end;

procedure TForm1.ButtonStopClick(Sender: TObject);

var
  Reply, BoxStyle: integer;

begin

  BoxStyle := MB_ICONQUESTION + MB_YESNO;
  Reply := Application.MessageBox('Are you sure you want to Stop?',
    'Question!', BoxStyle);

  if Reply = idYes then
    stoppressed := 1;

end;


procedure TForm1.ButtonstartClick(Sender: TObject);

var
  Reply, BoxStyle: integer;

begin

  stoppressed := 0;

  if trim(Fileswildcardedit.text)='' then
  begin
   ShowMessage('Files Wildcard is Empty!');
   exit;

  end;




  BoxStyle := MB_ICONQUESTION + MB_YESNO;
  Reply := Application.MessageBox('Please Backup Source before doing this!' +
    #13#10 + 'Continue?', 'Review your settings!', BoxStyle);

  if Reply = idNo then
    exit;


  try
    if not DirPathExists(EditSourcedir.Text) then
    begin
      ShowMessage(EditSourcedir.Text + ' Source Not Valid!');
      exit;
    end;


    memo1.Clear;


    editstatus.Text := '';



  except
    on E: Exception do
      DumpExceptionCallStack(E);
  end;

  statusstateenable(False);
  ProcessDir(EditSourceDir.Text);

end;



procedure TForm1.Memo1Change(Sender: TObject);

begin
  //if memo1.Lines.Count > 1000 then
  //  memo1.Lines.Delete(0);
end;

procedure TForm1.ProcessDir(const SourceDirName: string);

var
  i, fileindex,enddir: integer;

  files, Directories: TStringList;

  Attr: word;

  OurZipper: TZipper;
  compressedfiles, compressstart, compressstop, mspassedp, secpassed,
  totalcompresstime, filesizec, filesizeuc: int64;
  totalfilesizec, totalfilesizeuc: extended;
begin
  //starttime := getTickCount64;
  stoppressed := 0;
  totalfilesizec := 0;
  totalfilesizeuc := 0;
  compressedfiles := 0;
  totalcompresstime := 0;

  Memo1.Lines.Add('Please wait, this can take a long time if scanning many directories...');
  application.ProcessMessages;
  try
    try
      try

        if (recursivecheckbox.checked) then
        Directories := FindAllDirectories(SourceDirName, True)
        else
        Directories := FindAllDirectories(SourceDirName, false);

        //directories.Add(SourceDirName);
        directories.Insert(0,SourceDirName);
        if not (recursivecheckbox.Checked) then
        enddir:=0
        else
        enddir:=directories.count-1;
        for i := 0 to enddir do
        begin  //dir start
          application.ProcessMessages;
          if (stoppressed = 1) then
          begin

            Memo1.Lines.Add('Stop Pressed...');
            editstatus.Text := 'Stop Pressed...';
            //ShowMessage('Stop Pressed...');

            statusstateenable(True);
            exit;
          end;


          editstatus.Text := 'Processing Directory ' + IntToStr(i) +
            ' of ' + IntToStr(Directories.Count - 1);


          Memo1.Lines.Add('DI : [' + IntToStr(i) + '] ' + Directories.Strings[i]);



          if (FindAllFiles(Directories.Strings[i], Fileswildcardedit.text, False).Count > 0) then
          begin   //files start 2

            try
              files := findallfiles(Directories.Strings[i], Fileswildcardedit.text, False);


              for fileindex := 0 to files.Count - 1 do
              begin
                application.ProcessMessages;
                if (stoppressed = 1) then
                begin
                  Memo1.Lines.Add('Stop Pressed...');
                  editstatus.Text := 'Stop Pressed...';
                  //ShowMessage('Stop Pressed...');

                  statusstateenable(True);


                  exit;
                end;

                // readonly check and set start


                Attr := FileGetAttr(files.Strings[fileindex]);
                if ((Attr and faReadOnly) = faReadOnly) then
                  FileSetAttr(files.Strings[fileindex], Attr and (not faReadOnly));

                //readonly check and set end

                fileutil.DeleteFileUTF8(files.Strings[fileindex] + '.zip');
                //fileutil.DeleteFileUTF8(files.Strings[fileindex] + '.tmp');


                filesizeuc := fileutil.filesize(files.Strings[fileindex]);

                //zip start
                OurZipper := TZipper.Create;
                try
                  try
                    OurZipper.FileName := files.Strings[fileindex] + '.zip';
                    OurZipper.Entries.AddFileEntry(
                      files.Strings[fileindex],
                      extractfilename(files.Strings[fileindex]));
                    Memo1.Lines.Add('Compressing file : ' +
                      files.Strings[fileindex] + ' to ' +
                      files.Strings[fileindex] + '.zip');


                    compressstart := gettickcount64;
                    OurZipper.ZipAllFiles;
                    compressstop := gettickcount64;
                    totalcompresstime :=
                      totalcompresstime + (compressstop - compressstart);
                  finally
                    OurZipper.Free;
                  end;

                  //zip end

                except
                  on  E: Exception do
                  begin
                    fileutil.DeleteFileUTF8(files.Strings[fileindex] + '.zip');

                    editstatus.Text :=
                      'Failed to create Zip file : ' + files.Strings[fileindex] + '.zip';
                    Memo1.Lines.Add('Failed to create Zip file : ' +
                      files.Strings[fileindex] + '.zip : ' + e.message);


                    ShowMessage('Failed to create Zip file : ' +
                      files.Strings[fileindex] + '.zip : ' + e.message);
                    statusstateenable(True);
                    exit;

                  end;
                end;



                if (fileexists(files.Strings[fileindex] + '.zip')) then
                begin
                  compressedfiles := compressedfiles + 1;

                  filesizec := fileutil.filesize(files.Strings[fileindex] + '.zip');

                  if ((filesizeuc < 0) or (filesizec < 0)) then
                  begin
                    filesizeuc := 0;
                    filesizec := 0;
                  end;

                  totalfilesizec := totalfilesizec + (filesizec / 1048576);
                  totalfilesizeuc := totalfilesizeuc + (filesizeuc / 1048576);

                  Memo1.Lines.Add('Created Zip file : ' +
                    files.Strings[fileindex] + '.zip [' +
                    IntToStr(trunc(((filesizec / filesizeuc) * 100))) + '%]');
                  if (not fileutil.DeleteFileUTF8(files.Strings[fileindex])) then
                  begin
                    editstatus.Text :=
                      'Failed to delete file : ' + files.Strings[fileindex];
                    Memo1.Lines.Add('Failed to delete file : ' +
                      files.Strings[fileindex]);


                    ShowMessage('Failed to delete file : ' + files.Strings[fileindex]);
                    statusstateenable(True);
                    exit;

                  end
                  else
                  begin
                    Memo1.Lines.Add('Deleted ' + files.Strings[fileindex] +
                      ' because added to Zip : ' + files.Strings[fileindex] + '.zip');
                  end;

                end
                else
                begin
                  editstatus.Text :=
                    'Not deleted because Zip not found : ' +
                    files.Strings[fileindex] + '.zip';
                  Memo1.Lines.Add('Not deleted because Zip not found : ' +
                    files.Strings[fileindex] + '.zip');


                  ShowMessage('Not deleted because Zip not found : ' +
                    files.Strings[fileindex] + '.zip');
                  statusstateenable(True);
                  exit;
                end;
                //}

              end;

            finally
              files.Free;
            end;

          end; //files end 2
        end; //dir end


      finally
        directories.Free;
      end;




      //summary was here
    finally
      memo1.Lines.add('');
      memo1.Lines.add('Summary :');
      memo1.Lines.add('Total Files Processed : ' + IntToStr(compressedfiles));
      memo1.Lines.add('Total Uncompressed Size : ' +
        floattostr(totalfilesizeuc) + ' mb');
      memo1.Lines.add('Total Compressed Size : ' + floattostr(totalfilesizec) + ' mb');

      mspassedp := totalcompresstime;
      secpassed := trunc(mspassedp / 1000);


      if (totalfilesizeuc > 1) then
      begin

        memo1.Lines.add('Total Space Saved : ' +
          floattostr(totalfilesizeuc - totalfilesizec) + ' mb');
        memo1.Lines.add('Total Data Compression Ratio : ' + FloatToStr(
          totalfilesizeuc / totalfilesizec) + ':1');
        memo1.Lines.add('Total Space Savings : ' +
          IntToStr(trunc((1 - (totalfilesizec / totalfilesizeuc)) * 100)) + '%');

        if (secpassed > 0) then
          memo1.Lines.add('Total Compression Speed : ' +
            floatToStr(totalfilesizeuc / secpassed) + ' mb/second');


      end;
      memo1.Lines.add('Total Compression Time : [' +
        passedToHourMinSec(mspassedp) + ']');

      Memo1.Lines.Add('');
      Memo1.Lines.Add('MultiZipper Complete!');
      editstatus.Text := 'MultiZipper Complete!';
      ShowMessage('MultiZipper Complete!');

    end;

  except


    on E: Exception do
      DumpExceptionCallStack(E);

  end;


  statusstateenable(True);
end;


procedure TForm1.DumpExceptionCallStack(E: Exception);
var
  I: integer;
  Frames: PPointer;
  Report: string;
begin
  statusstateenable(True);
  Report := 'Program exception! ' + LineEnding + 'Stacktrace:' +
    LineEnding + LineEnding;
  if E <> nil then
  begin
    Report := Report + 'Exception class: ' + E.ClassName + LineEnding +
      'Message: ' + E.Message + LineEnding;
  end;
  Report := Report + BackTraceStrFunc(ExceptAddr);
  Frames := ExceptFrames;
  for I := 0 to ExceptFrameCount - 1 do
    Report := Report + LineEnding + BackTraceStrFunc(Frames[I]);

  Memo1.Lines.Add('Error Report: ' + Report);
  ShowMessage(Report);
  //Halt; // End of program execution
end;

procedure tform1.statusstateenable(locked: boolean);
begin

  buttonss.Enabled := locked;
  buttonstart.Enabled := locked;
  editsourcedir.Enabled := locked;
  Fileswildcardedit.enabled:=locked;
  recursiveCheckBox.enabled:=locked;

  application.ProcessMessages;

end;

function tform1.passedToHourMinSec(mspassed: integer): string;
var
  t: extended;

begin

  t := (mspassed) / (MSecsPerDay);
  Result := IntToStr(trunc(t)) + ':' + FormatDateTime('hh:nn:ss.zzz',
    t, [fdoInterval]);
end;

end.
