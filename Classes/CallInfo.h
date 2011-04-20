//
//  CallInfo.h
//  SipIPhone
//
// Created by iMac on 10/19/08.
// Copyright 2007 - 2008  Shanghai KaiWei Network Technology. All rights reserved.

//

#import <UIKit/UIKit.h>
//#import "general_call.h"

enum call_event_type {
	CALL_RING,
	CALL_HANGUP,
	CALL_CONNECTD,
	CALL_REGISTER,
	DISABLE_STUN_SERVER
};
	
@interface CallInfo : NSObject {
	enum call_event_type       eventtype;
	enum general_call_protocol calltype;
	const char *phonenum;
	int         callid;
	int         regid;
	int         result;
}

@property enum call_event_type       eventtype;
@property enum general_call_protocol calltype;
@property const char *phonenum;
@property int callid;
@property int regid;
@property int result;

@end
