unit pcmaudio;
{$mode objfpc}
{$modeswitch advancedrecords}

interface

uses fpwavformat;

type
	TPCMAudioInfo = record
		Channels: UInt16;
		SampleRate: UInt32;
		Depth: UInt16;
	end;

	TPCMAudioInfoHelper = record helper for TPCMAudioInfo
	private
		function ParseMIMEDepth(Specifier: AnsiString): Boolean;
		function ParseMIMETypeRC(MimeType: AnsiString): Boolean;
		function ParseMIMETypeCR(MimeType: AnsiString): Boolean;
	public
		function ParseMIMEType(MIMEType: AnsiString): Boolean;
		function ByteRate: UInt32;
		function BlockAlign: UInt16;
		function BitsPerSample: UInt16;
		function Samples(Seconds: Double): LongInt;
		function Bytes(Seconds: Double): LongInt;
		function Seconds(Octets: LongInt): Double;
		procedure ToWaveFormat(var WaveFormat: TWaveFormat);
	end;

implementation

uses regexpr, math;

const
	RCRegExpr: String = '^audio\/([lb]16);\s*rate=(\d+);\s*channels=(\d+)$';
	CRRegExpr: String = '^audio\/([lb]16);\s*channels=(\d+);\s*rate=(\d+)$';

function TPCMAudioInfoHelper.ParseMIMEDepth(Specifier: AnsiString): Boolean;
begin
	Result := False;
	case Specifier of
		'l16':
			begin
				Depth := 2;
				Result := True;
			end;
		'b16':
			begin
				Depth := 2;
				Result := True;
			end;
	end;
end;

function TPCMAudioInfoHelper.ParseMIMETypeRC(MIMEType: AnsiString): Boolean;
var
	RegExpr: TRegExpr;
begin
	Result := False;
	RegExpr := TRegExpr.Create(RCRegExpr);
	try
		if RegExpr.Exec(MIMEType) then
		begin
			ParseMIMEDepth(RegExpr.Match[1]);
			Val(RegExpr.Match[2], SampleRate);
			Val(RegExpr.Match[3], Channels);
			Result := True;
		end;
	finally
		RegExpr.Free;
	end;
end;

function TPCMAudioInfoHelper.ParseMIMETypeCR(MIMEType: AnsiString): Boolean;
var
	RegExpr: TRegExpr;
begin
	Result := False;
	RegExpr := TRegExpr.Create(CRRegExpr);
	try
		if RegExpr.Exec(MIMEType) then
		begin
			ParseMIMEDepth(RegExpr.Match[1]);
			Val(RegExpr.Match[2], Channels);
			Val(RegExpr.Match[3], SampleRate);
			Result := True;
		end;
	finally
		RegExpr.Free;
	end;
end;

function TPCMAudioInfoHelper.ParseMIMEType(MIMEType: AnsiString): Boolean;
begin
	Result := ParseMIMETypeRC(MIMEType) or ParseMIMETypeCR(MIMEType);
end;

function TPCMAudioInfoHelper.ByteRate: UInt32;
begin
	Result := Channels * SampleRate * Depth;
end;

function TPCMAudioInfoHelper.BlockAlign: UInt16;
begin
	Result := Channels * Depth;
end;

function TPCMAudioInfoHelper.BitsPerSample: UInt16;
begin
	Result := 8 * Depth;
end;

function TPCMAudioInfoHelper.Samples(Seconds: Double): LongInt;
begin
	Assert(not IsNaN(Seconds), 'Seconds is natural');
	Assert(not IsInfinite(Seconds), 'Seconds is natural');
	Result := Trunc(Seconds * SampleRate);
	Assert(Result >= 0, 'Samples>=0');
end;

function TPCMAudioInfoHelper.Bytes(Seconds: Double): LongInt;
begin
	Result := Samples(Seconds) * Channels * Depth;
	Assert(Result >= 0, 'Bytes>=0');
end;

function TPCMAudioInfoHelper.Seconds(Octets: LongInt): Double;
begin
	Assert(Octets >= 0, 'Octets>=0');
	Result := Octets / ByteRate;
	Assert(Result >= 0, 'Seconds>=0');
end;

procedure TPCMAudioInfoHelper.ToWaveFormat(var WaveFormat: TWaveFormat);
begin
	WaveFormat.Channels := Channels;
	WaveFormat.SampleRate := SampleRate;
	WaveFormat.ByteRate := ByteRate;
	WaveFormat.BlockAlign := BlockAlign;
	WaveFormat.BitsPerSample := BitsPerSample;
end;

end.
