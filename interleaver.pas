unit interleaver;
{$mode objfpc}

interface

uses classes, sysutils, contnrs;

type
	TInterleavedStreamProcObject = procedure (AStream: TStream; out AContinue: Boolean) of object;
	TInterleavedStreamProc = procedure (AInfo: Pointer; AStream: TStream; out AContinue: Boolean);
	TInterleaver = class(TComponent)
	private
		FOutput: TStream;
		FStreams: TObjectBucketList;
		FBlockSize: LongInt;
		FCount: LongInt;
	protected
		procedure Empty(AStream: TStream; var Missing: LongInt); virtual;
	public
		constructor Create(AOwner: TComponent); override;
		procedure Add(AStream: TStream; IsOwner: Boolean = False);
		function Remove(AStream: TStream): Boolean;
		procedure ForEach(AProc: TInterleavedStreamProcObject); overload;
		procedure ForEach(AProc: TInterleavedStreamProc; AInfo: Pointer = nil); overload;
		function InterleaveOnce: LongInt;
		procedure InterleaveUntilEOF;
		destructor Destroy; override;
		property Output: TStream read FOutput write FOutput;
		property BlockSize: LongInt read FBlockSize write FBlockSize;
		property Count: LongInt read FCount;
	end;

implementation

type
	PInterleavedStreamProcObject = ^TInterleavedStreamProcObject;
	TInterleavedStreamProcInfo = record
		Proc: TInterleavedStreamProc;
		Info: Pointer;
	end;
	PInterleavedStreamProcInfo = ^TInterleavedStreamProcInfo;
	TCopyBlockInfo = record
		Interleaver: TInterleaver;
		Done: LongInt;
	end;
	PCopyBlockInfo = ^TCopyBlockInfo;

constructor TInterleaver.Create(AOwner: TComponent);
begin
	FStreams := TObjectBucketList.Create;
	FCount := 0;
	inherited;
end;

procedure TInterleaver.Empty(AStream: TStream; var Missing: LongInt);
begin
	(* Empty default implementation *)
end;

procedure TInterleaver.Add(AStream: TStream; IsOwner: Boolean = False);
begin
	if IsOwner then
		FStreams.Add(AStream, AStream)
	else
		FStreams.Add(AStream, nil);
	Inc(FCount);
end;

function TInterleaver.Remove(AStream: TStream): Boolean;
begin
	Result := False;
	if Assigned(FStreams.Remove(AStream)) then
	begin
		Dec(FCount);
		Result := True;
	end;
end;

procedure CallWithStreamAndInfo(AInfo, AItem, AData: Pointer; out AContinue: Boolean);
begin
	Assert(Assigned(AInfo), 'AInfo is not nil');
	Assert(Assigned(AItem), 'AItem is not nil');
	with PInterleavedStreamProcInfo(AInfo)^ do
	begin
		Proc(Info, TStream(AItem), AContinue);
	end;
end;

procedure TInterleaver.ForEach(AProc: TInterleavedStreamProc; AInfo: Pointer);
var
	Info: TInterleavedStreamProcInfo;
begin
	Info.Proc := AProc;
	Info.Info := AInfo;
	FStreams.ForEach(@CallWithStreamAndInfo, @Info);
end;

procedure CallWithStream(AInfo, AItem, AData: Pointer; out AContinue: Boolean);
begin
	Assert(Assigned(AInfo), 'AInfo is not nil');
	Assert(Assigned(AItem), 'AItem is not nil');
	PInterleavedStreamProcObject(AInfo)^(TStream(AItem), AContinue);
end;

procedure TInterleaver.ForEach(AProc: TInterleavedStreamProcObject);
begin
	FStreams.ForEach(@CallWithStream, @AProc);
end;

procedure CopyBlock(AInfo, AItem, AData: Pointer; out AContinue: Boolean);
var
	Buffer: array of Byte;
begin
	with PCopyBlockInfo(AInfo)^ do
	begin
		SetLength(Buffer, Interleaver.BlockSize);
		TStream(AItem).Read(Buffer[0], Interleaver.BlockSize);
		Interleaver.Output.Write(Buffer[0], Interleaver.BlockSize);
		if TStream(AItem).Position >= TStream(AItem).Size then
			Inc(Done);
	end;
end;

function TInterleaver.InterleaveOnce: LongInt;
var
	CopyBlockInfo: TCopyBlockInfo;
begin
	Assert(FBlockSize > 0, 'FBlockSize is greater than 0');
	Assert(Assigned(FOutput), 'FOutput is assigned');
	with CopyBlockInfo do
	begin
		Interleaver := Self;
		Done := 0;
	end;
	FStreams.ForEach(@CopyBlock, @CopyBlockInfo);
	Result := CopyBlockInfo.Done;
end;

procedure TInterleaver.InterleaveUntilEOF;
begin
	while InterleaveOnce < FCount do
	begin
	end;
end;

procedure DestroyStream(AInfo, AItem, AData: Pointer; out AContinue: Boolean);
begin
	TStream(AData).Free;
	AContinue := True;
end;

destructor TInterleaver.Destroy;
begin
	FStreams.ForEach(@DestroyStream);
	FreeAndNil(FStreams);
	inherited;
end;

end.

