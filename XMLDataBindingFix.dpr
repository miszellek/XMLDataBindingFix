// JCL_DEBUG_EXPERT_GENERATEJDBG OFF
// JCL_DEBUG_EXPERT_INSERTJDBG OFF
program XMLDataBindingFix;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  System.IOUtils,
  System.RegularExpressions,
  System.StrUtils;

var
  FileName: string;
  XML: string;
  NS: string;
  RTTI: Boolean;
  RegEx: TRegEx;
  Match: TMatch;
  XMLClass: string;
  InterfaceProperty: string;

begin
  try

    FileName := ParamStr(ParamCount);
    if not FileExists(FileName) then
    begin
      raise Exception.Create('Delphi pas file "' + FileName + '" not found');
    end;

    if FindCmdLineSwitch('NS', NS, True, [clstValueAppended]) then
    begin
      if NS = '' then
        raise Exception.Create('No namespace defined. Use -NS:namespace');
    end;

    RTTI := FindCmdLineSwitch('RTTI', ['/', '-'], True);

    if FindCmdLineSwitch('?') or (ParamCount = 0) or (not RTTI and (NS = '')) then
    begin
      WriteLn('XMLDataBindingFix for Delphi version 0.1 license MIT');
      WriteLn('');
      WriteLn('Usage: XMLDataBindingFix [-NS:namespace] [-RTTI] PasFileName');
      WriteLn('');
      WriteLn('Available options: ');
      WriteLn('  -NS            NameSpace prefix');
      WriteLn('  -RTTI          Copy property from interace to class for rtti access');
      WriteLn('  -PasFileName   XML Data Binding pas file');
      WriteLn('');
      WriteLn('');
      WriteLn('Example: XMLDataBindingFix -NS:tns -RTTI XSD.pas');
      Exit;
    end;

    XML := TFile.ReadAllText(FileName, TEncoding.ANSI);

    // add namespace for helper
    if NS <> '' then
    begin
      // ChildNodes\[WideString\('(.*?)'\)\]
      // ChildNodes['\1']
      XML := TRegEx.Replace(XML, 'ChildNodes\[WideString\(''(.*?)''\)\]', 'ChildNodes[''$1'']');

      // ChildNodes['
      // ChildNodes['tns:
      XML := TRegEx.Replace(XML, 'ChildNodes\[''(((?!:).)*)''', 'ChildNodes[''' + NS + ':$1''');

      // RegisterChildNode('
      // RegisterChildNode('tns:
      XML := TRegEx.Replace(XML, 'RegisterChildNode\(''(((?!:).)*)''', 'RegisterChildNode(''' + NS + ':$1''');

      // ItemTag := '
      // ItemTag := 'tns:
      XML := TRegEx.Replace(XML, 'ItemTag\ :=\ ''(((?!:).)*)''', 'ItemTag := ''' + NS + ':$1''');

      // (CreateCollection\(.+?,.+?, ')(.+?)\)
      // \1tns:\2\)
      XML := TRegEx.Replace(XML, '(CreateCollection\(.+?,.+?,[\t\ ]*'')(((?!:).)*)\)', '$1' + NS + ':$2)');

      //GetDocBinding('
      //GetDocBinding('tns:
      XML := TRegEx.Replace(XML, 'GetDocBinding\(''(((?!:).)*)''', 'GetDocBinding(''' + NS + ':$1''');
    end;

    // add property in class for rtti
    if RTTI then
    begin
      for Match in TRegEx.Create('IXML(\w*?)\ ?=\ ?interface\(.*?\{\ Methods\ &\ Properties\ \}(.*?)end;', [roIgnoreCase, roSingleLine, roCompiled]).Matches(XML) do // interface
      begin
        if Match.Groups.Count = 3 then
        begin
          RegEx := TRegEx.Create('TXML' + Match.Groups[1].Value + '\ ?=\ ?class\(.*?end;', [roSingleLine]); // class
          if RegEx.Match(XML).Success then
          begin
            XMLClass := RegEx.Match(XML).Value;

            InterfaceProperty := TRegEx.Create('^((?!property).)*$', [roMultiLine, roIgnoreCase]).Replace(Match.Groups[2].Value, ''); // only property
            InterfaceProperty := TRegEx.Create('^\h*\R', [roMultiLine]).Replace(InterfaceProperty, ''); // remove empty lines

            if not XMLClass.Contains(InterfaceProperty) then
              XML := XML.Replace(XMLClass, TRegEx.Create('^\s*end;$', [roMultiLine]).Replace(XMLClass, IfThen(not XMLClass.ToLower.Contains('published'), '  published' + #13#10, '') + InterfaceProperty + 'end;'));
          end;
        end;
      end;
    end;

    TFile.WriteAllText(ChangeFileExt(FileName, '_' + ExtractFileExt(FileName)), XML, TEncoding.ANSI);

  except
    on E: Exception do
      WriteLn(E.ClassName, ': ', E.Message);
  end;

end.
