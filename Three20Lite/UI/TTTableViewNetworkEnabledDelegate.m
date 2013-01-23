//
// Copyright 2009-2011 Facebook
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "TTTableViewNetworkEnabledDelegate.h"

// UI
#import "TTTableHeaderDragRefreshView.h"
#import "TTTableViewController.h"
#import "UIViewAdditions.h"

// UICommon
#import "TTGlobalUICommon.h"

// Network
#import "TTModel.h"

// Style
#import "TTGlobalStyle.h"
#import "TTDefaultStyleSheet+DragRefreshHeader.h"

// Core
#import "TTCorePreprocessorMacros.h"


// The number of pixels the table needs to be pulled down by in order to initiate the refresh.
static const CGFloat kRefreshDeltaY = -65.0f;

// The height of the refresh header when it is in its "loading" state.
static const CGFloat kHeaderVisibleHeight = 60.0f;

// The height of the infinite scroll footer view
static const CGFloat kInfiniteScrollFooterHeight = 40.0f;

// The percentage of table scrolling to trigger infinite scroll agter
static const CGFloat kInfiniteScrollThreshold = 0.5f;


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
@implementation TTTableViewNetworkEnabledDelegate

@synthesize headerView = _headerView,
            dragRefreshEnabled = _dragRefreshEnabled;

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NSObject


///////////////////////////////////////////////////////////////////////////////////////////////////
- (id)initWithController:(TTTableViewController*)controller
         withDragRefresh:(BOOL)enableDragRefresh
      withInfiniteScroll:(BOOL)enableInfiniteScroll {
	self = [super initWithController:controller];
  if (self) {
    _dragRefreshEnabled = enableDragRefresh;

    // Hook up to the model to listen for changes.
    _model = [controller.model retain];
    [_model.delegates addObject:self];

    if (_dragRefreshEnabled) {
      // Add our refresh header
      _headerView = [[TTTableHeaderDragRefreshView alloc]
                     initWithFrame:CGRectMake(0,
                                              -_controller.tableView.bounds.size.height,
                                              _controller.tableView.width,
                                              _controller.tableView.bounds.size.height)];
      _headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
      _headerView.backgroundColor = TTSTYLEVAR(tableRefreshHeaderBackgroundColor);
      [_headerView setStatus:TTTableHeaderDragRefreshPullToReload];
      [_controller.tableView addSubview:_headerView];


      // Grab the last refresh date if there is one.
      if ([_model respondsToSelector:@selector(loadedTime)] && enableDragRefresh) {
        NSDate* date = [_model performSelector:@selector(loadedTime)];

        if (nil != date) {
          [_headerView setUpdateDate:date];
        }
      }
    }
  }
  return self;
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)dealloc {
  _controller.tableView.tableFooterView = nil;
  [_model.delegates removeObject:self];
  [_headerView removeFromSuperview];
  TT_RELEASE_SAFELY(_headerView);
  TT_RELEASE_SAFELY(_model);

  [super dealloc];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark UIScrollViewDelegate


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)scrollViewDidScroll:(UIScrollView*)scrollView {
  [super scrollViewDidScroll:scrollView];

  if (_dragRefreshEnabled) {
    if (scrollView.dragging && !_model.isLoading) {
      if (scrollView.contentOffset.y > kRefreshDeltaY
          && scrollView.contentOffset.y < 0.0f) {
        [_headerView setStatus:TTTableHeaderDragRefreshPullToReload];

      } else if (scrollView.contentOffset.y < kRefreshDeltaY) {
        [_headerView setStatus:TTTableHeaderDragRefreshReleaseToReload];
      }
    }

    // This is to prevent odd behavior with plain table section headers. They are affected by the
    // content inset, so if the table is scrolled such that there might be a section header abutting
    // the top, we need to clear the content inset.
    if (_model.isLoading) {
      if (scrollView.contentOffset.y >= 0) {
        _controller.tableView.contentInset = UIEdgeInsetsZero;

      } else if (scrollView.contentOffset.y < 0) {
        _controller.tableView.contentInset = UIEdgeInsetsMake(kHeaderVisibleHeight, 0, 0, 0);
      }
    }
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)scrollViewDidEndDragging:(UIScrollView*)scrollView willDecelerate:(BOOL)decelerate {
  [super scrollViewDidEndDragging:scrollView willDecelerate:decelerate];

  if (_dragRefreshEnabled) {
    // If dragging ends and we are far enough to be fully showing the header view trigger a
    // load as long as we arent loading already
    if (scrollView.contentOffset.y <= kRefreshDeltaY && !_model.isLoading) {
      [[NSNotificationCenter defaultCenter]
       postNotificationName:@"DragRefreshTableReload" object:nil];
      [_model load:TTURLRequestCachePolicyNetwork more:NO];
    }
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark TTModelDelegate


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)modelDidStartLoad:(id<TTModel>)model {
  if (_dragRefreshEnabled) {
    [_headerView setStatus:TTTableHeaderDragRefreshLoading];

    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:ttkDefaultFastTransitionDuration];
    if (_controller.tableView.contentOffset.y < 0) {
      _controller.tableView.contentInset = UIEdgeInsetsMake(kHeaderVisibleHeight, 0.0f, 0.0f, 0.0f);
    }
    [UIView commitAnimations];
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)modelDidFinishLoad:(id<TTModel>)model {
  if (_dragRefreshEnabled) {
    [_headerView setStatus:TTTableHeaderDragRefreshPullToReload];

    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:ttkDefaultTransitionDuration];
    _controller.tableView.contentInset = UIEdgeInsetsZero;
    [UIView commitAnimations];

    if ([model respondsToSelector:@selector(loadedTime)]) {
      NSDate* date = [model performSelector:@selector(loadedTime)];
      [_headerView setUpdateDate:date];

    } else {
      [_headerView setCurrentDate];
    }
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)model:(id<TTModel>)model didFailLoadWithError:(NSError*)error {
  if (_dragRefreshEnabled) {
    [_headerView setStatus:TTTableHeaderDragRefreshPullToReload];

    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:ttkDefaultTransitionDuration];
    _controller.tableView.contentInset = UIEdgeInsetsZero;
    [UIView commitAnimations];
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)modelDidCancelLoad:(id<TTModel>)model {
  if (_dragRefreshEnabled) {
    [_headerView setStatus:TTTableHeaderDragRefreshPullToReload];

    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:ttkDefaultTransitionDuration];
    _controller.tableView.contentInset = UIEdgeInsetsZero;
    [UIView commitAnimations];
  }
}


@end
