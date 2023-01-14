unit curlpcmmix;
{$mode objfpc}

interface

uses classes, sysutils, math, interleaver, contnrs, notifystreams, pcmaudio, flowstats, curlex, curlexopt, curlstreams, libcurl, dateutils, curlexhelpers, fpwavwriter, fpwavformat;

type
	EPCMMIMETypeError = class(Exception);

	TCurlPCMResponseReaderStream = class;

	TPCMResponseWritten = procedure (Sender: TCurlPCMResponseReaderStream) of object;

	TCurlPCMResponseReaderStream = class(TCurlResponseReaderStream)
	private
		FAudioInfo: TPCMAudioInfo;
		FAfterPCMWrite: TPCMResponseWritten;
	protected
		procedure Response(Code: LongInt; ContentType: PChar); override;
		procedure AfterWrite; override;
	public
		property AudioInfo: TPCMAudioInfo read FAudioInfo;
		property AfterPCMWrite: TPCMResponseWritten read FAfterPCMWrite write FAfterPCMWrite;
	end;

	TCurlPCMMultiplexer = class(TCurlMultiplexer)
	private
		FWavWriter: TWavWriter;
		FInterleaver: TInterleaver;
		procedure AfterClientAdded(AClient: TCurlClient);
		procedure AfterClientDone(AClient: TCurlClient; Code: CURLCode);
		procedure AfterAnyPCMWrite(Sender: TCurlPCMResponseReaderStream);
		procedure Prepare(AStream: TStream; out AContinue: Boolean);
		procedure Clear(AStream: TStream; out AContinue: Boolean);
	protected
		procedure Elapsed; override;
	public
		constructor Create(AOwner: TComponent; AStream: TStream); reintroduce;
		destructor Destroy; override;
	end;

implementation

type
	TStreamMuxData = record
		WavWriter: TWavWriter;
		Done: Integer;
	end;
	PStreamMuxData = ^TStreamMuxData;
	TEveryStreamData = record
		Position: Int64;
		Every: Boolean;
	end;
	PEveryStreamData = ^TEveryStreamData;

procedure TCurlPCMResponseReaderStream.Response(Code: LongInt; ContentType: PChar);
begin
	if not FAudioInfo.ParseMIMEType(ContentType) then
		raise EPCMMIMETypeError.Create('invalid PCM MIME type');
	writeln('CHN ', AudioInfo.Channels, ' ', UInt64(Pointer(Self)));
end;

procedure TCurlPCMResponseReaderStream.AfterWrite;
begin
	if Assigned(FAfterPCMWrite) then
		FAfterPCMWrite(Self);
end;

constructor TCurlPCMMultiplexer.Create(AOwner: TComponent; AStream: TStream);
begin
	inherited Create(AOwner);
	FInterleaver := TInterleaver.Create(Self);
	FWavWriter := TWavWriter.Create;
	with FWavWriter.fmt do
	begin
		Format := WAVE_FORMAT_PCM;
		Channels := 2;
		SampleRate := 8000;
		ByteRate := SampleRate * Channels * 2;
		BlockAlign := Channels * 2;
		BitsPerSample := 16;
	end;
	FInterleaver.BlockSize := 2;
	FInterleaver.Output := AStream;
	FWavWriter.StoreToStream(AStream);
	MultiClient.ClientAdded := @AfterClientAdded;
	MultiClient.ClientDone := @AfterClientDone;
end;

destructor TCurlPCMMultiplexer.Destroy;
begin
	FreeAndNil(FWavWriter);
	inherited;
end;

procedure TCurlPCMMultiplexer.AfterClientDone(AClient: TCurlClient; Code: CURLCode);
begin
	//AClient.Free;
end;

procedure TCurlPCMMultiplexer.Prepare(AStream: TStream; out AContinue: Boolean);
begin
	Assert(Assigned(AStream), 'AStream is not nil');
	AStream.Position := 0;
	AContinue := True;
end;

procedure TCurlPCMMultiplexer.Clear(AStream: TStream; out AContinue: Boolean);
var
	Stream: TStream;
begin
	Stream := TOwnerStream(AStream);
	while Stream is TOwnerStream do
		Stream := TOwnerStream(Stream).Source;
	Assert(Stream is TMemoryStream, 'Stream is TMemoryStream');
	TMemoryStream(Stream).Clear;
	TMemoryStream(Stream).Position := 0;
	AContinue := True;
end;

procedure TCurlPCMMultiplexer.Elapsed;
begin
	FInterleaver.ForEach(@Prepare);
	FInterleaver.InterleaveUntilEOF;
	FInterleaver.ForEach(@Clear);
end;

procedure EveryPosition(AInfo: Pointer; Stream: TStream; out AContinue: Boolean);
begin
	with PEveryStreamData(AInfo)^ do
	begin
		Every := Every and (Stream.Position >= Position);
		AContinue := Every;
	end;
end;

procedure TCurlPCMMultiplexer.AfterAnyPCMWrite(Sender: TCurlPCMResponseReaderStream);
var
	Data: TEveryStreamData;
begin
	Data.Position := 2;
	Data.Every := True;
	FInterleaver.ForEach(@EveryPosition, @Data);
	if Data.Every then
	   Elapsed;
end;

procedure TCurlPCMMultiplexer.AfterClientAdded(AClient: TCurlClient);
var
	Stream: TMemoryStream;
	ResponseReaderStream: TCurlPCMResponseReaderStream;
begin
	Stream := TMemoryStream.Create;
	ResponseReaderStream := TCurlPCMResponseReaderStream.Create(Stream);
	with ResponseReaderStream do
	begin
		SourceOwner := True;
		Client := AClient;
		AfterPCMWrite := @AfterAnyPCMWrite;
	end;
	FInterleaver.Add(ResponseReaderStream);
	TCurlStreamOption.Create(AClient, ResponseReaderStream, True);
	writeln('Client added');
end;

end.

