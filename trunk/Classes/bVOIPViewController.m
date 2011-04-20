//
//  bVOIPViewController.m
//  bVOIP
//
//  
//Copyright (C) 2011  Brian Green

//This program is free software; you can redistribute it and/or
//modify it under the terms of the GNU General Public License
//as published by the Free Software Foundation; either version 2
//of the License, or (at your option) any later version.

//This program is distributed in the hope that it will be useful,
//but WITHOUT ANY WARRANTY; without even the implied warranty of
//MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//GNU General Public License for more details.

//You should have received a copy of the GNU General Public License
//along with this program; if not, write to the Free Software
//Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

#include <pthread.h>
#include <stdio.h>

#include <pjsua-lib/pjsua.h>
#define THIS_FILE	"APP"
static pjsua_acc_id acc_id = PJSUA_INVALID_ID;
#import "bVOIPViewController.h"



@implementation bVOIPViewController


void pjsip_hangup()
{
	if (acc_id!=PJSUA_INVALID_ID) {
		pjsua_msg_data msg_data;
		
		pjsua_msg_data_init(&msg_data);
		
		pjsua_call_hangup  (acc_id, 200, 0, 0);  
		
	}
	
}

static void error_exit(const char *title, pj_status_t status)
{
    pjsua_perror(THIS_FILE, title, status);
    pjsua_destroy();
    //exit(1);
}

int pjsip_regist_account(char* sip_user, char* sip_passwd, char* sip_domain, char* sip_realm)
{
    /* Register to SIP server by creating SIP account. */
	pjsua_acc_config cfg;
	
	pjsua_acc_config_default(&cfg);
	
	char string_id[1024];
	char string_reg_uri[1024];
	
	sprintf(string_id, "sip:%s@%s", sip_user, sip_domain);
	cfg.id = pj_str(string_id);
	sprintf(string_reg_uri, "sip:%s", sip_domain);
	cfg.reg_uri = pj_str(string_reg_uri);
	cfg.cred_count = 1;
	cfg.cred_info[0].realm = pj_str(sip_realm);
	cfg.cred_info[0].scheme = pj_str("digest");
	cfg.cred_info[0].username = pj_str(sip_user);
	cfg.cred_info[0].data_type = PJSIP_CRED_DATA_PLAIN_PASSWD;
	cfg.cred_info[0].data = pj_str(sip_passwd);
	
    pj_status_t status;
	status = pjsua_acc_add(&cfg, PJ_TRUE, &acc_id);
	if (status != PJ_SUCCESS) 
	{
		error_exit("Error adding account", status);
		return 0;
    }
	
	return 1;
}
static void on_call_media_state(pjsua_call_id call_id)
{
    pjsua_call_info ci;
	
    pjsua_call_get_info(call_id, &ci);

    if (ci.media_status == PJSUA_CALL_MEDIA_ACTIVE) {
		// When media is active, connect call to sound device.
		pjsua_conf_connect(ci.conf_slot, 0);
		pjsua_conf_connect(0, ci.conf_slot);
    }
}

static void on_call_state(pjsua_call_id call_id, pjsip_event *e)
{
    pjsua_call_info ci;
	
    PJ_UNUSED_ARG(e);
	
    pjsua_call_get_info(call_id, &ci);
    PJ_LOG(3,(THIS_FILE, "Call %d state=%.*s", call_id,
			  (int)ci.state_text.slen,
			  ci.state_text.ptr));
}

static void on_incoming_call(pjsua_acc_id acc_id, pjsua_call_id call_id,
							 pjsip_rx_data *rdata)
{
    pjsua_call_info ci;
	
    PJ_UNUSED_ARG(acc_id);
    PJ_UNUSED_ARG(rdata);
	
    pjsua_call_get_info(call_id, &ci);
	
    PJ_LOG(3,(THIS_FILE, "Incoming call from %.*s!!",
			  (int)ci.remote_info.slen,
			  ci.remote_info.ptr));
	
    /* Automatically answer incoming calls with 200/OK */
    pjsua_call_answer(call_id, 200, NULL, NULL);
	//[Button setTitle:@"Hangup" forState:UIControlStateNormal];
}

int pjsip_make_call(char* sip_url)
{
    /* If argument is specified, it's got to be a valid SIP URL */
    pj_status_t status = pjsua_verify_sip_url(sip_url);
	if (status != PJ_SUCCESS) 
	{
		error_exit("Invalid call URL", status);
		return 0;
	}
	
    /* If URL is specified, make call to the URL. */
	pj_str_t uri = pj_str(sip_url);
	status = pjsua_call_make_call(acc_id, &uri, 0, NULL, NULL, NULL);
	printf("\n\nacc_id=%d\n\n",acc_id);

	if (status != PJ_SUCCESS) 
	{
		error_exit("Error making call", status);
		return 0;
    }
	
	return 1;
}

int pjsip_init(const char*stun_server, const char *logfile)
{
    pj_status_t status;
	
    /* Create pjsua first! */
    status = pjsua_create();
    if (status != PJ_SUCCESS) 
	{
		error_exit("Error in pjsua_create()", status);
		return 0;
	}
	
    /* Init pjsua */
    {
		pjsua_config cfg;
		pjsua_logging_config log_cfg;
		
		pjsua_config_default(&cfg);
		cfg.cb.on_incoming_call = &on_incoming_call;
		cfg.cb.on_call_media_state = &on_call_media_state;
		cfg.cb.on_call_state = &on_call_state;
		if (stun_server && stun_server[0]) {
			cfg.stun_host =  pj_str(stun_server);
		}
		pjsua_logging_config_default(&log_cfg);
		log_cfg.console_level = 5;
		log_cfg.level = 4;
		log_cfg.log_filename = pj_str(logfile);
		
		status = pjsua_init(&cfg, &log_cfg, NULL);
		if (status != PJ_SUCCESS) 
		{
			error_exit("Error in pjsua_init()", status);
			return 0;
		}
    }
	
    /* Add UDP transport. */
    {
		pjsua_transport_config cfg;
		
		pjsua_transport_config_default(&cfg);
		cfg.port = 5060;
		status = pjsua_transport_create(PJSIP_TRANSPORT_UDP, &cfg, NULL);
		if (status != PJ_SUCCESS) 
		{
			error_exit("Error creating transport", status);
			return 0;
		}
    }
	
    /* Initialization is done, now start pjsua */
    status = pjsua_start();
    if (status != PJ_SUCCESS) 
	{
		error_exit("Error starting pjsua", status);
		return 0;
	}
	
	return 1;
}

/*
// The designated initializer. Override to perform setup that is required before the view is loaded.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}
*/

/*
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
}
*/

-(void)test4{
	//pjsua_destroy();	
//	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  //  NSString *documentsDirectory = [paths objectAtIndex:0];
	//NSString *log = [documentsDirectory stringByAppendingPathComponent:@"sipphone.log"];
	//NSLog(@"THEFILE=%@",[NSMutableString stringWithContentsOfFile:log encoding:NSASCIIStringEncoding error:NULL]);

}

-(void)test3{
	pjsua_destroy();	
	
	
}

-(void)kill_pjsua{
pjsua_destroy();	
}

-(void)test2{
	printf("\n\nacc_id=%d\n\n",acc_id);
	pjsua_call_hangup  (0, 200, 0, 0);

}

-(void)test{
	pjsip_make_call("sip:6001@192.168.2.6");	
}

-(IBAction)digitPressed:(id)sender{
	UIButton *aButton = sender;
	//if ([dialField.text isEqualToString:@""]) dialField.text = aButton.titleLabel;
	 dialField.text = [NSString stringWithFormat:@"%@%@",dialField.text,aButton.currentTitle];
}
-(IBAction)clearText:(id)sender{
dialField.text = @"";	
}
-(IBAction)call:(id)sender{
	UIButton *aButton = sender;
	if ([aButton.currentTitle isEqualToString:@"Call"]) {
	NSString *b = [NSString stringWithFormat:@"sip:%@@voip.server.com",dialField.text];
	pjsip_make_call((char*)[b UTF8String]);
		[aButton setTitle:@"Hangup" forState:UIControlStateNormal];
	}else {
		pjsua_call_hangup(0, 200, 0, 0);
		pjsua_call_hangup(1, 200, 0, 0);
		pjsua_call_hangup(2, 200, 0, 0);
		pjsua_call_hangup(3, 200, 0, 0);
		[aButton setTitle:@"Call" forState:UIControlStateNormal];
	}

	
}
// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
	

	if (pjsip_init(NULL,NULL))
		pjsip_regist_account("YourUsername", "password", "server", "realm");
    
	
	[super viewDidLoad];
}



/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}


- (void)dealloc {
    [super dealloc];
}

@end
