unit curlex;
{$mode objfpc}

interface

uses sysutils, classes, fgl, contnrs, libcurl, dateutils;

type
	ECurlError = class(Exception);

	TCurlOption = class(TComponent)
	protected
		procedure Configure(Curl: PCurl); virtual; abstract;
		procedure Deconfigure(Curl: PCurl); virtual; abstract;
	end;

	TCurlClient = class(TComponent)
	private
		FCurl: PCurl;
		FCode: CURLCode;
		procedure AfterOptionAdded(Option: TCurlOption);
		procedure BeforeOptionRemoved(Option: TCurlOption);
		procedure OptionOperation(Option: TCurlOption; Operation: TOperation);
	protected
		procedure Notification(AComponent: TComponent; Operation: TOperation); override;
	public
		constructor Create(AOwner: TComponent = nil); override;
		destructor Destroy; override;
		procedure Perform;
		property Handle: PCurl read FCurl;
		property Code: CURLCode read FCode;
	end;

	TCurlClientOperation = procedure (Client: TCurlClient) of object;
	TCurlMultiClientMessageHandler = procedure (Client: TCurlClient; Code: CURLCode) of object;

	TCurlMultiClient = class(TComponent)
	private
		FCurlM: PCurlM;
		FRunning: LongInt;
		FHandles: TBucketList;
		FCode: CURLMCode;
		FClientDone: TCurlMultiClientMessageHandler;
		FClientAdded: TCurlClientOperation;
		procedure AfterClientDone(Curl: PCurl; Code: CURLCode);
		procedure ProcessClientMessages;
		procedure AfterClientAdded(Client: TCurlClient);
		procedure BeforeClientRemoved(Client: TCurlClient);
		procedure ClientOperation(Client: TCurlClient; Operation: TOperation);
	protected
		procedure Notification(AComponent: TComponent; Operation: TOperation); override;
	public
		constructor Create(AOwner: TComponent = nil); override;
		destructor Destroy; override;
		procedure Perform;
		procedure Wait(timeout: LongInt = 0);
		property Running: LongInt read FRunning;
		property Code: CURLMCode read FCode;
		property ClientDone: TCurlMultiClientMessageHandler read FClientDone write FClientDone;
		property ClientAdded: TCurlClientOperation read FClientAdded write FClientAdded;
	end;

	TCurlMultiplexer = class(TComponent)
	private
		FMultiClient: TCurlMultiClient;
		FTimeout: LongInt;
	protected
		procedure Elapsed; virtual;
	public
		constructor Create(AOwner: TComponent); override;
		procedure Loop;
		property Timeout: LongInt read FTimeout write FTimeout;
		property MultiClient: TCurlMultiClient read FMultiClient;
	end;

implementation

constructor TCurlClient.Create(AOwner: TComponent);
begin
	FCurl := curl_easy_init;
	if not Assigned(FCurl) then
		raise ECurlError.Create('curl_easy_init() failed');
	inherited;
end;

procedure TCurlClient.AfterOptionAdded(Option: TCurlOption);
begin
	Assert(Assigned(FCurl), 'Curl handle<>nil');
	Option.Configure(FCurl);
end;

procedure TCurlClient.BeforeOptionRemoved(Option: TCurlOption);
begin
	Assert(Assigned(FCurl), 'Curl handle<>nil');
	Option.Deconfigure(FCurl);
end;

procedure TCurlClient.OptionOperation(Option: TCurlOption; Operation: TOperation);
begin
	case Operation of
		opInsert : AfterOptionAdded(Option);
		opRemove : BeforeOptionRemoved(Option);
	end;
end;

procedure TCurlClient.Notification(AComponent: TComponent; Operation: TOperation);
begin
	if AComponent is TCurlOption then
		OptionOperation(TCurlOption(AComponent), Operation);
	inherited;
end;

procedure TCurlClient.Perform;
begin
	Assert(Assigned(FCurl), 'Curl handle<>nil');
	FCode := curl_easy_perform(FCurl);
	if FCode <> CURLE_OK then
		raise ECurlError.Create('curl_easy_perform() failed');
end;

destructor TCurlClient.Destroy;
begin
	inherited;
	if Assigned(FCurl) then
	begin
		curl_easy_cleanup(FCurl);
		FCurl := nil;
	end;
end;


constructor TCurlMultiClient.Create(AOwner: TComponent);
begin
	FHandles := TBucketList.Create;
	FCurlM := curl_multi_init;
	if not Assigned(FCurlM) then
		raise ECurlError.Create('curl_multi_init() failed');
	inherited;
end;

procedure TCurlMultiClient.AfterClientAdded(Client: TCurlClient);
begin
	Assert(Assigned(Client), 'Client<>nil');
	Assert(Assigned(Client.Handle), 'Client handle<>nil');
	Assert(Assigned(FCurlM), 'Curl handle<>nil');
	FCode := curl_multi_add_handle(FCurlM, client.Handle);
	if FCode <> CURLM_OK then
		raise ECurlError.Create('curl_multi_add_handle() failed');
	FHandles.Add(client.Handle, client);
	if Assigned(FClientAdded) then
		FClientAdded(Client);
end;

procedure TCurlMultiClient.BeforeClientRemoved(Client: TCurlClient);
begin
	Assert(Assigned(Client), 'Client<>nil');
	Assert(Assigned(Client.Handle), 'Client handle<>nil');
	Assert(Assigned(FCurlM), 'Curl handle<>nil');
	FCode := curl_multi_remove_handle(FCurlM, client.Handle);
	if FCode <> CURLM_OK then
		raise ECurlError.Create('curl_multi_remove_handle() failed');
	FHandles.Remove(client.Handle);
end;

procedure TCurlMultiClient.ClientOperation(Client: TCurlClient; Operation: TOperation);
begin
	case Operation of
		opInsert : AfterClientAdded(Client);
		opRemove : BeforeClientRemoved(Client);
	end;
end;

procedure TCurlMultiClient.Notification(AComponent: TComponent; Operation: TOperation);
begin
	Assert(Assigned(AComponent), 'Component<>nil');
	if AComponent is TCurlClient then
		ClientOperation(TCurlClient(AComponent), operation);
end;

procedure TCurlMultiClient.AfterClientDone(Curl: PCurl; Code: CURLCode);
var
	CurlClientPointer: Pointer = nil;
begin
	Assert(Assigned(FHandles), 'FHandles<>nil');
	FHandles.Find(Curl, CurlClientPointer);
	Assert(Assigned(CurlClientPointer), 'Client lookup for cURL handle');
	if Assigned(FClientDone) then
		FClientDone(TCurlClient(CurlClientPointer), Code);
end;

procedure TCurlMultiClient.ProcessClientMessages;
var
	PMessage: PCURLMsg;
	MessagesInQueue: LongInt = 0;
begin
	Assert(Assigned(FCurlM), 'Curl handle<>nil');
	PMessage := curl_multi_info_read(FCurlM, @MessagesInQueue);
	while Assigned(PMessage) do
	begin
		case PMessage^.msg of
			CURLMSG_DONE : AfterClientDone(PMessage^.easy_handle, PMessage^.data.result);
		end;
		if MessagesInQueue > 0 then
			PMessage := curl_multi_info_read(FCurlM, @MessagesInQueue)
		else
			PMessage := nil;
	end;
end;

procedure TCurlMultiClient.Perform;
begin
	Assert(Assigned(FCurlM), 'Curl handle<>nil');
	FCode := curl_multi_perform(FCurlM, @FRunning);
	if FCode <> CURLM_OK then
		raise ECurlError.Create('curl_multi_perform() failed');
	ProcessClientMessages;
end;

procedure TCurlMultiClient.Wait(Timeout: longint);
begin
	Assert(Assigned(FCurlM), 'Curl handle<>nil');
	Assert(Timeout >= 0, 'Timeout must be >=0');
	FCode := curl_multi_wait(FCurlM, nil, 0, Timeout, nil);
	if FCode <> CURLM_OK then
		raise ECurlError.Create('curl_multi_wait() failed');
end;

destructor TCurlMultiClient.Destroy;
begin
	if Assigned(FCurlM) then
	begin
		FCode := curl_multi_cleanup(FCurlM);
		if FCode = CURLM_OK then
			FCurlM := nil
	end;
	inherited;
end;

constructor TCurlMultiplexer.Create(AOwner: TComponent);
begin;
	FMultiClient := TCurlMultiClient.Create(Self);
	inherited;
end;

procedure TCurlMultiplexer.Elapsed;
begin;
end;

procedure TCurlMultiplexer.Loop;
var
	Start: Double;
	Remaining: LongInt;
begin
	Assert(Assigned(FMultiClient), 'FClient<>nil');
	Assert(FTimeout >= 0, 'FTimeout is natural');
	FMultiClient.Perform;
	Remaining := FTimeout;
	while FMultiClient.Running > 0 do
	begin
		Start := Now;
		FMultiClient.Wait(Remaining);
		Dec(Remaining, Trunc(MilliSecondSpan(Now, Start)));
		if Remaining <= 0 then
		begin
			Elapsed;
			Assert(FTimeout >= 0, 'FTimeout is natural');
			Inc(Remaining, FTimeout);
			if Remaining < 0 then
				Remaining := 0;
		end;
		FMultiClient.Perform;
	end;
	Elapsed;
end;

end.

