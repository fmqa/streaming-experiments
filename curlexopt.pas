unit curlexopt;
{$mode objfpc}

interface

uses classes, sysutils, contnrs, curlex, libcurl, unixtype;

type
	TCurlURLOption = class(TCurlOption)
	private
		FTarget: AnsiString;
	protected
		procedure Configure(Curl: PCurl); override;
		procedure Deconfigure(Curl: PCurl); override;
	public
		constructor Create(AOwner: TComponent; ATarget: AnsiString); reintroduce;
		property Target: AnsiString read FTarget;
	end;

	TCurlStreamOption = class(TCurlOption)
	private
		FStream: TStream;
		FOwner: Boolean;
	protected
		procedure Configure(Curl: PCurl); override;
		procedure Deconfigure(Curl: PCurl); override;
	public
		constructor Create(AOwner: TComponent; AStream: TStream; Owned: Boolean = False); reintroduce;
		destructor Destroy; override;
		property Owner: Boolean read FOwner write FOwner;
	end;

	TCurlHeaderDictOption = class(TCurlOption)
	private
		FTable: TFPStringHashTable;
		FOwner: Boolean;
	protected
		procedure Configure(Curl: PCurl); override;
		procedure Deconfigure(Curl: PCurl); override;
	public
		constructor Create(AOwner: TComponent; ATable: TFPStringHashTable; Owned: Boolean = False); reintroduce;
		destructor Destroy; override;
		property Table: TFPStringHashTable read FTable;
		property Owner: Boolean read FOwner write FOwner;
	end;

implementation

function WriteToStream(data: Pointer; size, nmemb: size_t; opaque: Pointer): size_t; cdecl;
begin
	Assert(Assigned(data), 'data<>nil');
	Assert(Assigned(opaque), 'opaque<>nil');
	Result := TStream(opaque).Write(data^, size * nmemb);
end;

procedure AddToTable(Table: TFPStringHashTable; Fields: array of AnsiString);
var
	Key: AnsiString;
	Data: AnsiString;
begin
	Assert(Assigned(Table), 'Table<>nil');
	if Length(fields) = 2 then
	begin
		Key := Fields[0].Trim();
		Data := Fields[1].Trim();
		if (not Key.IsEmpty) and (not Data.isEmpty) then
		begin
			Table.Delete(Key);
			Table.Add(Key, Data);
		end;
	end;
end;

function ReadHeader(data: Pointer; size, nitems: size_t; opaque: Pointer): size_t; cdecl;
var
	Header: AnsiString;
begin
	Assert(Assigned(data), 'data<>nil');
	Assert(Assigned(opaque), 'opaque<>nil');
	Assert(size >= 0, 'size>=0');
	Assert(nitems >= 0, 'nitems>=0');
	SetString(Header, PChar(data), size * nitems);
	AddToTable(TFPStringHashTable(opaque), Header.Split(':'));
	Result := size * nitems;
end;

constructor TCurlURLOption.Create(AOwner: TComponent; ATarget: AnsiString);
begin
	FTarget := ATarget;
	inherited Create(AOwner);
end;

procedure TCurlURLOption.Configure(Curl: PCurl);
var
	CTarget: PChar;
begin
	Assert(Assigned(Curl), 'handle<>nil');
	CTarget := PChar(FTarget);
	Assert(Assigned(CTarget), 'ctarget<>nil');
	curl_easy_setopt(Curl, CURLOPT_URL, [CTarget]);
end;

procedure TCurlURLOption.Deconfigure(Curl: PCurl);
begin
	Assert(Assigned(Curl), 'handle<>nil');
	curl_easy_setopt(Curl, CURLOPT_URL, [nil]);
end;

constructor TCurlStreamOption.Create(AOwner: TComponent; AStream: TStream; Owned: Boolean);
begin
	FStream := AStream;
	FOwner := Owned;
	inherited Create(AOwner);
end;

procedure TCurlStreamOption.Configure(Curl: PCurl);
begin
	Assert(Assigned(Curl), 'handle<>nil');
	if Assigned(FStream) then
	begin
		curl_easy_setopt(Curl, CURLOPT_WRITEFUNCTION, [@WriteToStream]);
		curl_easy_setopt(Curl, CURLOPT_WRITEDATA, [Pointer(FStream)]);
	end;
end;

procedure TCurlStreamOption.Deconfigure(Curl: PCurl);
begin
	Assert(Assigned(Curl), 'handle<>nil');
	curl_easy_setopt(Curl, CURLOPT_WRITEFUNCTION, [nil]);
	curl_easy_setopt(Curl, CURLOPT_WRITEDATA, [nil]);
end;

destructor TCurlStreamOption.Destroy;
begin
	if FOwner then
		FreeAndNil(FStream);
	inherited;
end;

constructor TCurlHeaderDictOption.Create(AOwner: TComponent; ATable: TFPStringHashTable; Owned: Boolean);
begin
	FTable := ATable;
	FOwner := Owned;
	inherited Create(AOwner);
end;

procedure TCurlHeaderDictOption.Configure(Curl: PCurl);
begin
	Assert(Assigned(Curl), 'handle<>nil');
	if Assigned(FTable) then
	begin
		curl_easy_setopt(Curl, CURLOPT_HEADERFUNCTION, [@ReadHeader]);
		curl_easy_setopt(Curl, CURLOPT_HEADERDATA, [Pointer(FTable)]);
	end;
end;

procedure TCurlHeaderDictOption.Deconfigure(Curl: PCurl);
begin
	Assert(Assigned(Curl), 'handle<>nil');
	curl_easy_setopt(Curl, CURLOPT_HEADERFUNCTION, [nil]);
	curl_easy_setopt(Curl, CURLOPT_HEADERDATA, [nil]);
end;

destructor TCurlHeaderDictOption.Destroy;
begin
	if FOwner then
		FreeAndNil(FTable);
	inherited;
end;

end.

