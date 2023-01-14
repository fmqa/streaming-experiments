unit wavstreams;
{$mode objfpc}

interface

uses classes, sysutils, fpwavwriter;

type
	TWavWriterStream = class(TStream)
	private
		FWavWriter: TWavWriter;
		FOwner: Boolean;
	public
		constructor Create(AWavWriter: TWavWriter; AOwner: Boolean);
		function Write(const Buffer; Count: LongInt): LongInt; overload;
		destructor Destroy; override;
	end;

implementation

constructor TWavWriterStream.Create(AWavWriter: TWavWriter; AOwner: Boolean);
begin
	FWavWriter := AWavWriter;
	FOwner := AOwner;
	inherited Create;
end;

function TWavWriterStream.Write(const Buffer; Count: LongInt): LongInt;
begin
	Result := FWavWriter.WriteBuf(Buffer, Count);
end;

destructor TWavWriter.Destroy;
begin
	if FOwner then
		FreeAndNil(FWavWriter);
	inherited;
end;

end.
