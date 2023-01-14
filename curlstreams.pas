unit curlstreams;
{$mode objfpc}

interface

uses curlex, curlexhelpers, notifystreams;

type
	TCurlResponseReaderStream = class(TObservedWriteStream)
	private
		FClient: TCurlClient;
	protected
		procedure BeforeFirstWrite; override;
		procedure Response(Code: LongInt; ContentType: PChar); virtual;
	public
		property Client: TCurlClient read FClient write FClient;
	end;

implementation

procedure TCurlResponseReaderStream.Response(Code: LongInt; ContentType: PChar);
begin;
	(* Empty default implementation *)
end;

procedure TCurlResponseReaderStream.BeforeFirstWrite;
var
	Code: LongInt;
	ContentType: PChar;
begin
	Assert(Assigned(FClient), 'Client is not nil');
	Code := FClient.ResponseCode;
	Assert(Code <> 0, 'ResponseCode is nonzero');
	ContentType := FClient.ContentType;
	Assert(Assigned(ContentType), 'ContentType is not nil');
	Response(Code, ContentType);
end;

end.
