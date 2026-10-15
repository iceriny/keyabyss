"""Correct committed words and characters, with right-censored end-of-test input."""
import numpy as np

def aligned_correct_letters(target,typed):
    """Matches on a minimum-edit alignment; deterministic tie-breaking."""
    n=len(target);m=len(typed)
    d=np.zeros((n+1,m+1),int);matches=np.zeros_like(d)
    d[:,0]=np.arange(n+1);d[0,:]=np.arange(m+1)
    for i in range(1,n+1):
        for j in range(1,m+1):
            eq=target[i-1]==typed[j-1]
            choices=[(d[i-1,j-1]+int(not eq),matches[i-1,j-1]+int(eq)),
                     (d[i-1,j]+1,matches[i-1,j]),(d[i,j-1]+1,matches[i,j-1])]
            cost,best=min(choices,key=lambda z:(z[0],-z[1]));d[i,j]=cost;matches[i,j]=best
    return int(matches[n,m]),int(d[n,m])

def score_words(words,events,duration):
    committed=[w for w in words if w['submit_time']<=duration]
    exact=sum(int(w['correct']) for w in committed)
    letters=0;distance=0;target_chars=0
    for w in committed:
        if w['correct']: letters+=len(w['word'])
        else:
            matches,edits=aligned_correct_letters(w['word'],w['typed']);letters+=matches;distance+=edits
        target_chars+=len(w['word'])+1
    # A submit counts as a correct space only if the submitted word is correct.
    chars=letters+exact
    keys=[e for e in events if e.get('key') and e['time']<=duration]
    back=sum(e.get('key')=='\b' for e in keys)
    error_count=sum(w['motor_errors']+int(w['recognition_error'])+int(w['memory_error']) for w in committed)
    minutes=duration/60.
    return dict(wpm5=chars/(5*minutes),actual_wpm=exact/minutes,lpm=letters/minutes,cpm=chars/minutes,
        raw_kpm=len(keys)/minutes,completed_words=exact,submitted_words=len(committed),
        completion_rate=exact/max(len(committed),1),uncorrected_error=distance/max(target_chars,1),
        corrected_errors_per_char=error_count/max(target_chars,1),backspace_ratio=back/max(len(keys),1),
        backspaces=back,raw_key_count=len(keys),correct_letters=letters,correct_characters=chars)
