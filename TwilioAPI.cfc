component output="false" {
	/*
	* @hint init function for persistence
	*/
	public TwilioAPI function init(string accountSID, string authToken, string fromNumber, string twilioVer='2010-04-01', boolean developmentMode=False) 
	{	
		/* replaced the implicit getter & setters with a config function fr decoupling/publishing */
		this.twilioConfig 	= StructNew();
		this.errors 		= ArrayNew(1);

		setupTwilioConfig(argumentCollection = Arguments);

		return this;
	}

	private struct function twilioRequest(string requestType='', struct requestParams=StructNew(), string RequestMethod='')
	{
		var data 		= StructNew();
		var returnData 	= StructNew();

		try 
		{
			returnData.success 	= False;
			returnData.errors 	= ArrayNew(1);
			returnData.response = StructNew();

			data.twilioURL = getTwilioURL(requestType=Arguments.requestType);

		}
		catch (any errorItem)
		{
			errorLogging(returnData.errors, errorItem);
		}


		if (ArrayLen(returnData.errors) == 0)
		{
			try 
			{
				/*
					CF9+ version. CF11+ can use the scripted cfhttp commented out below
				*/
				data.httpService = new http(method="GET", url=data.twilioURL, charset="utf-8"); 

				data.httpService.addParam(name="From", type="formfield", value=getTwilioFromNumber()); 

				for (data.key in Arguments.requestParams)
				{
					data.httpService.addParam(name=REReplace(Trim(data.key), "\b(\S)(\S*)\b", "\u\1\L\2", "all" ), type="formfield", value=Arguments.requestParams[data.key]);
				}

				data.result 		= data.httpService.send().getPrefix(); 

				/*
					CF11+ version

					cfhttp(method="GET", charset="utf-8", url=data.twilioURL, result="data.result") 
					{
    					cfhttpparam(name="From", type="formfield", value=getTwilioFromNumber());

    					for (data.key in Arguments.requestParams)
						{
							cfhttpparam(name=REReplace(Trim(data.key), "\b(\S)(\S*)\b", "\u\1\L\2", "all" ), type="formfield", value=Arguments.requestParams[data.key]);
						}
					}
				*/

				returnData.response = data.result;
			}
			catch (any errorItem)
			{
				errorLogging(returnData.Errors, errorItem);
			}
		}

		return returnData;
	}

	public struct function sendTwilioSMSMessage(string to='', string body='')
	{
		var data 		= StructNew();
		var returnData 	= StructNew();

		try 
		{
			returnData.processSuccess	= False;
			returnData.errors 			= ArrayNew(1);
			returnData.responseContent 	= '';
			returnData.responseHeader	= '';

			data.sendMessage = twilioRequest(requestType="SMS", requestParams=Arguments);

			if (structKeyExists(data.sendMessage, "errors") && IsArray(data.sendMessage.errors) && ArrayLen(data.sendMessage.errors))
			{
				returnData.errors = Duplicate(data.sendMessage.errors);
			}
			else {
				returnData.responseContent 	= Duplicate(data.sendMessage.response.fileContent);
				returnData.responseHeader 	= Duplicate(data.sendMessage.response.responseHeader);
			}
			
			returnData.processSuccess = True;
		}
		catch (any errorItem) 
		{
			errorLogging(returnData.errors, errorItem);
		}

		return returnData;
	}

	public struct function checkTwilioUsageStats()
	{
		var data 		= StructNew();
		var returnData 	= StructNew();

		try 
		{
			returnData.unparsedData = StructNew();
			returnData.parsedData 	= StructNew();
			returnData.errors 		= ArrayNew(1);

			data.usageRequest 		= twilioRequest(RequestType="Usage", RequestParams=StructNew(), RequestMethod="Get");
			returnData.unparsedData = Duplicate(data.usageRequest.twilio.fileContent); 
			returnData.parsedData 	= DeserializeJSON(returnData.unparsedData);
		}
		catch (any errorItem)
		{
			errorLogging(returnData.errors, errorItem);
		}

		return returnData;
	}

	private void function setupTwilioConfig(boolean developmentMode=False, string accountSID='', string authToken='', string fromNumber='', string twilioVer='2010-04-01' )
	{

		try {
			this.twilioConfig.developmentMode 	= Arguments.developmentMode;
			this.twilioConfig.accountSID 		= Arguments.accountSID;
			this.twilioConfig.authToken 		= Arguments.authToken;
			this.twilioConfig.fromNumber 		= Arguments.fromNumber;
			this.twilioConfig.twilioVer 		= Arguments.twilioVer;

			this.twilioConfig.twilioURL 		= StructNew();
			this.twilioConfig.twilioURL.base 	= 'https://api.twilio.com/' & Arguments.twilioVer & '/Accounts/' & Arguments.accountSID & '/';
			this.twilioConfig.twilioURL.SMS 			= this.twilioConfig.twilioURL.base & 'Messages';
			this.twilioConfig.twilioURL.monthlyUsage 	= this.twilioConfig.twilioURL.base & 'Usage/Records.json';
			this.twilioConfig.twilioURL.messages 		= this.twilioConfig.twilioURL.base & 'Messages.json';

		}

		catch (any errorItem) 
		{
			this.errors = errorLogging(this.errors, errorItem);
		}
	}

	public string function getTwilioURL(string requestType='')
	{
		switch (LCase(Trim(Arguments.requestType))) {
			case "sms":
				return this.twilioConfig.twilioURL.SMS;

			case "usage":
				return this.twilioConfig.twilioURL.monthlyUsage;

			case "messages":
				return this.twilioConfig.twilioURL.messages;

			default: 
				return this.twilioConfig.base;
		}
	}

	public array function errorLogging(array errorArray, any errorCatch)
	{
		var ReturnData = ArrayNew(1);

		ReturnData = Duplicate(Arguments.errorArray);
		ArrayAppend(ReturnData, Arguments.errorCatch.message & ' - ' & Arguments.errorCatch.detail);
		
		if (this.twilioConfig.developmentMode) 
		{
			writeDump(Arguments);
			abort;
		}

		return ReturnData;
	}

	private string function getTwilioFromNumber(){
		return this.twilioConfig.fromNumber;
	}
}