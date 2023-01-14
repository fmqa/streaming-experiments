program downloader;
{$mode objfpc}

uses classes, sysutils, curlex, curlexopt, curlpcmmix;

procedure DispTable(Item: AnsiString; const Key: AnsiString; var Continue: Boolean);
begin
	writeln(Key, '=', Item);
	Continue := true;
end;

const
	testA: String = 'http://127.0.0.1:8080';
	testB: String = 'http://127.0.0.1:8081';
var
	clientA: TCurlClient;
	clientB: TCurlClient;
	mix: TCurlPCMMultiplexer;
	outfs: TFileStream;
begin
	outfs := TFileStream.Create('mix.wav', fmCreate);
	mix := TCurlPCMMultiplexer.Create(nil, outfs);
	mix.Timeout := 5000;
	try
		clientA := TCurlClient.Create(mix.MultiClient);
		clientB := TCurlClient.Create(mix.MultiClient);

		TCurlURLOption.Create(clientA, testA);
		TCurlURLOption.Create(clientB, testB);

		mix.Loop;
	finally
		FreeAndNil(mix);
		FreeAndNil(outfs);
	end;
end.
