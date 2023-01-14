unit flowstats;
{$mode objfpc}

interface

uses classes, sysutils, math, dateutils;

type
	TTimeSpan = function (const ANow: TDateTime; const AThen: TDateTime): Double;

	TFlowInfo = class
	private
		FTotal: LongInt;
		FCount: LongInt;
		FLast: Double;
		FDelta: Double;
		FNum: LongInt;
		FAvgDelta: Double;
		FRate: Double;
		FAvgRate: Double;
	public
		property Total: LongInt   read FTotal;
		property Delta: Double    read FDelta;
		property AvgDelta: Double read FAvgDelta;
		property Rate: Double     read FRate;
		property AvgRate: Double  read FAvgRate;
	end;

	TFlow = class(TFlowInfo)
	private
		FTimeSpan: TTimeSpan;
		procedure Update(Current: Double);
	public
		constructor Create(ATimeSpan: TTimeSpan);
		procedure Clear;
		procedure Process(Time: Double; Count: LongInt);
	end;

	TFlowComponent = class(TComponent)
	private
		FFlow: TFlow;
		function GetTotal: LongInt;
		function GetDelta: Double;
		function GetAvgDelta: Double;
		function GetRate: Double;
		function GetAvgRate: Double;
	public
		constructor Create(AOwner: TComponent; ATimeSpan: TTimeSpan); reintroduce;
		destructor Destroy; override;
		procedure Clear;
		procedure Process(Time: Double; Count: LongInt);
		property Flow: TFlow      read FFlow;
		property Total: LongInt   read GetTotal;
		property Delta: Double    read GetDelta;
		property AvgDelta: Double read GetAvgDelta;
		property Rate: Double     read GetRate;
		property AvgRate: Double  read GetAvgRate;
	end;

	TWriteFlowStream = class(TOwnerStream)
	private
		FFlow: TFlow;
		function GetFlow: TFlowInfo;
	public
		constructor Create(ASource: TStream; ATimeSpan: TTimeSpan);
		destructor Destroy; override;
		function Write(const Buffer; Count: LongInt): LongInt; override;
		function Read(var Buffer; Count: LongInt): LongInt; override;
		function Seek(Offset: LongInt; Origin: Word): LongInt; override;
		property Flow: TFlowInfo read GetFlow;
	end;

implementation

constructor TFlow.Create(ATimeSpan: TTimeSpan);
begin
	inherited Create;
	FTimeSpan := ATimeSpan;
	Clear;
end;

procedure TFlow.Clear;
begin
	FTotal := 0;
	FCount := 0;
	FLast := NaN;
	FDelta := 0;
	FRate := 0;
	FNum := 0;
	FAvgDelta := 0;
	FAvgRate := 0;
	FAvgRate := 0;
end;

procedure TFlow.Update(Current: Double);
begin
	Assert(Assigned(FTimeSpan), 'FTimespan<>nil');
	Assert(Current >= 0, 'Current timestamp in bounds');
	Assert(not IsInfinite(Current), 'Current timestamp is finite');
	Assert(not IsNaN(Current), 'Current timestamp is not NaN');
	FDelta := FTimeSpan(Current, FLast);
	if FDelta > 0 then
		FRate := FCount / FDelta;
	FAvgDelta := FAvgDelta + (FDelta - FAvgDelta) / FNum;
	FAvgRate := FAvgRate + (FRate - FAvgRate) / FNum;
end;

procedure TFlow.Process(Time: Double; Count: LongInt);
begin
	Assert(Count >= 0, 'Count in bounds');
	Assert(Time >= 0, 'Current timestamp in bounds');
	Assert(not IsInfinite(Time), 'Current timestamp is finite');
	Assert(not IsNaN(Time), 'Current timestamp is not NaN');
	Inc(FNum);
	if not IsNaN(FLast) then
		Update(Time);
	FLast := Time;
	FCount := Count;
	Inc(FTotal, Count);
end;

constructor TFlowComponent.Create(AOwner: TComponent; ATimeSpan: TTimeSpan);
begin
	FFlow := TFlow.Create(ATimeSpan);
	inherited Create(AOwner);
end;

destructor TFlowComponent.Destroy;
begin
	FreeAndNil(FFlow);
	inherited;
end;

procedure TFlowComponent.Clear;
begin
	FFlow.Clear;
end;

procedure TFlowComponent.Process(Time: Double; Count: LongInt);
begin
	FFlow.Process(Time, Count);
end;

function TFlowComponent.GetTotal: LongInt;
begin
	Result := FFlow.Total;
end;

function TFlowComponent.GetDelta: Double;
begin
	Result := FFlow.Delta;
end;

function TFlowComponent.GetAvgDelta: Double;
begin
	Result := FFlow.AvgDelta;
end;

function TFlowComponent.GetRate: Double;
begin
	Result := FFlow.Rate;
end;

function TFlowComponent.GetAvgRate: Double;
begin
	Result := FFlow.AvgRate;
end;

constructor TWriteFlowStream.Create(ASource: TStream; ATimeSpan: TTimeSpan);
begin
	inherited Create(ASource);
	FFlow := TFlow.Create(ATimeSpan);
end;

destructor TWriteFlowStream.Destroy;
begin
	FreeAndNil(FFlow);
	inherited;
end;

function TWriteFlowStream.GetFlow: TFlowInfo;
begin
	Result := FFlow;
end;

function TWriteFlowStream.Write(const Buffer; Count: LongInt): LongInt;
begin
	Result := Source.Write(Buffer, Count);
	FFlow.Process(Now, Result);
end;

function TWriteFlowStream.Read(var Buffer; Count: LongInt): LongInt;
begin
	Result := Source.Read(Buffer, Count);
end;

function TWriteFlowStream.Seek(Offset: LongInt; Origin: Word): LongInt;
begin
	Result := Source.Seek(Offset, Origin);
end;

end.
