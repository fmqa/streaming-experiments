unit notifystreams;
{$mode objfpc}

interface

uses classes;

type
	TNotifyingWriteStream = class(TOwnerStream)
	protected
		procedure BeforeWrite; virtual;
		procedure AfterWrite; virtual;
	public
		function Write(const Buffer; Count: LongInt): LongInt; override;
		function Read(var Buffer; Count: LongInt): LongInt; override;
		function Seek(Offset: LongInt; Origin: Word): LongInt; override;
	end;

	TObservedWriteStream = class(TNotifyingWriteStream)
	private
		FCalled: Boolean;
	protected
		procedure BeforeFirstWrite; virtual;
		procedure AfterFirstWrite; virtual;
	public
		function Write(const Buffer; Count: LongInt): LongInt; override;
	end;

implementation

(* TNotifyingWriteStream *)

procedure TNotifyingWriteStream.BeforeWrite;
begin
	(* Empty default implementation *)
end;

procedure TNotifyingWriteStream.AfterWrite;
begin
	(* Empty default implementation *)
end;

function TNotifyingWriteStream.Write(const Buffer; Count: LongInt): LongInt;
begin
	BeforeWrite;
	Result := Source.Write(Buffer, Count);
	AfterWrite;
end;

function TNotifyingWriteStream.Read(var Buffer; Count: LongInt): LongInt;
begin
	Result := Source.Read(Buffer, Count);
end;

function TNotifyingWriteStream.Seek(Offset: LongInt; Origin: Word): LongInt;
begin
	Result := Source.Seek(Offset, Origin);
end;

(* TObservedWriteStream *)

procedure TObservedWriteStream.BeforeFirstWrite;
begin
	(* Empty default implementation *)
end;

procedure TObservedWriteStream.AfterFirstWrite;
begin
	(* Empty default implementation *)
end;

function TObservedWriteStream.Write(const Buffer; Count: LongInt): LongInt;
begin
	if not FCalled then
		BeforeFirstWrite;
	Result := inherited;
	if not FCalled then
		AfterFirstWrite;
	FCalled := True;
end;

end.
