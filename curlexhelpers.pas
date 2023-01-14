unit curlexhelpers;
{$mode objfpc}

interface

uses curlex, libcurl;

type
	TCurlClientHelper = class helper for TCurlClient
	private
		function GetResponseCode: LongInt;
		function GetContentType: PChar;
	public
		property ResponseCode: LongInt read GetResponseCode;
		property ContentType: PChar read GetContentType;
	end;

implementation

function TCurlClientHelper.GetResponseCode: LongInt;
begin
	Result := 0;
	curl_easy_getinfo(Handle, CURLINFO_RESPONSE_CODE, [@Result]);
end;

function TCurlClientHelper.GetContentType: PChar;
begin
	Result := nil;
	curl_easy_getinfo(Handle, CURLINFO_CONTENT_TYPE, [@Result]);
end;

end.

