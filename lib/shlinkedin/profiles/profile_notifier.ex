defmodule Shlinkedin.Profiles.ProfileNotifier do
  alias Shlinkedin.Profiles.{Profile, Endorsement, Testimonial, Notification}
  alias Shlinkedin.Timeline.{Like, Comment, Post, CommentLike}
  alias Shlinkedin.Timeline
  alias Shlinkedin.News.Vote
  alias Shlinkedin.News.Article
  alias Shlinkedin.Ads.Ad
  alias Shlinkedin.Groups.Group
  alias Shlinkedin.Groups
  alias Shlinkedin.Groups.Invite

  @doc """
  Deliver instructions to confirm account.
  """
  def observer({:ok, res}, type, %Profile{} = from \\ %Profile{}, %Profile{} = to \\ %Profile{}) do
    from_profile = Shlinkedin.Profiles.get_profile_by_profile_id_preload_user(from.id)
    to_profile = Shlinkedin.Profiles.get_profile_by_profile_id_preload_user(to.id)

    case type do
      :post ->
        notify_comment(from_profile, to_profile, res)

      :comment ->
        notify_comment(from_profile, to_profile, res)

      :like ->
        notify_like(from_profile, to_profile, res)

      :comment_like ->
        notify_comment_like(from_profile, to_profile, res)

      :vote ->
        notify_vote(from_profile, to_profile, res)

      :endorsement ->
        notify_endorsement(from_profile, to_profile, res)

      :testimonial ->
        notify_testimonial(from_profile, to_profile, res)

      :sent_friend_request ->
        notify_sent_friend_request(from_profile, to_profile)

      :accepted_friend_request ->
        notify_accepted_friend_request(from_profile, to_profile)

      :featured_post ->
        notify_post_featured(to_profile, res)

      :new_badge ->
        notify_profile_badge(to_profile, res)

      :jab ->
        notify_jab(from_profile, to_profile)

      :ad_click ->
        notify_ad_click(from_profile, to_profile, res)

      :new_group_member ->
        notify_new_group_member(from_profile, res)

      :sent_group_invite ->
        notify_group_invite(from_profile, to_profile, res)
    end

    {:ok, res}
  end

  def notify_group_invite(
        %Profile{} = from_profile,
        %Profile{} = to_profile,
        %Invite{} = invite
      ) do
    group = Groups.get_group!(invite.group_id)

    body = """

    Hi #{to_profile.persona_name},

    <br/>
    <br/>

    #{from_profile.persona_name} has invited you the #{group.privacy_type} group they are in, "#{
      group.title
    }." To accept or reject their invite,
    you can <a href="shlinked.herokuapp.com/groups/#{group.id}">click here.</a>

    <br/>
    <br/>
    Thanks, <br/>
    ShlinkTeam

    """

    Shlinkedin.Profiles.create_notification(%Notification{
      from_profile_id: from_profile.id,
      to_profile_id: to_profile.id,
      group_id: group.id,
      type: "group_invite",
      action: "invited you to join #{group.title}",
      body: ""
    })

    if to_profile.unsubscribed == false do
      Shlinkedin.Email.new_email(
        to_profile.user.email,
        "#{from_profile.persona_name} invited you to join #{group.title}",
        body
      )
      |> Shlinkedin.Mailer.deliver_later()
    end
  end

  def notify_new_group_member(%Profile{} = new_profile, %Group{} = group) do
    for member <- Shlinkedin.Groups.list_members(group) do
      if member.profile_id != new_profile.id do
        Shlinkedin.Profiles.create_notification(%Notification{
          from_profile_id: new_profile.id,
          to_profile_id: member.profile_id,
          type: "new_group_member",
          group_id: group.id,
          action: "joined a group you are in: ",
          body: "#{group.title}. Welcome them!"
        })
      end
    end
  end

  def notify_jab(
        %Profile{} = from_profile,
        %Profile{} = to_profile
      ) do
    body = """

    Hi #{to_profile.persona_name},

    <br/>
    <br/>

    #{from_profile.persona_name} has business jabbed you! Time to take
    some corporate revenge and <a href="shlinked.herokuapp.com/sh/#{from_profile.slug}">jab them back.</a>

    <br/>
    <br/>
    Thanks, <br/>
    ShlinkTeam

    """

    Shlinkedin.Profiles.create_notification(%Notification{
      from_profile_id: from_profile.id,
      to_profile_id: to_profile.id,
      type: "jab",
      action: "business jabbed you!",
      body: "Get some corporate revenge and jab them back!"
    })

    if to_profile.unsubscribed == false do
      Shlinkedin.Email.new_email(
        to_profile.user.email,
        "#{from_profile.persona_name} business jabbed you!",
        body
      )
      |> Shlinkedin.Mailer.deliver_later()
    end
  end

  def notify_sent_friend_request(
        %Profile{} = from_profile,
        %Profile{} = to_profile
      ) do
    Shlinkedin.Profiles.create_notification(%Notification{
      from_profile_id: from_profile.id,
      to_profile_id: to_profile.id,
      type: "pending_shlink",
      action: "has sent you a Shlink request!",
      body: ""
    })

    body = """

    Hi #{to_profile.persona_name},

    <br/>
    <br/>

    <p>Hi #{from_profile.persona_name} / #{from_profile.real_name} has sent you a Shlink request. You can accept it
    <a href="shlinked.herokuapp.com/sh/#{to_profile.slug}">here.</a>

    Time to think of some ice-breakers, like:</p>

    <ul>
    #{for line <- friend_request_text(), do: "<li>#{line}</li>"}
    </ul>

    <p>Happy shlinking!</p>

    <br/>
    <br/>
    Thanks, <br/>
    ShlinkTeam

    """

    if to_profile.unsubscribed == false do
      Shlinkedin.Email.new_email(
        to_profile.user.email,
        "#{from_profile.persona_name} has sent you a shlink request!",
        body
      )
      |> Shlinkedin.Mailer.deliver_later()
    end
  end

  defp friend_request_text() do
    [
      [
        "What’s the secret to your success?",
        "What are your business interests?",
        "How did your last relationship end?",
        "Whose fault was it?",
        "Do you still think about it?"
      ],
      [
        "Where do you see yourself in 100 years?",
        "If you could talk to yourself as a 10 year, or another 10 year old, uh, nevermind."
      ],
      [
        "How many conferences do you attend per year?",
        "What’s better, spiders or scorpions?"
      ],
      [
        "How long have you been in your line of work?",
        "How do you keep employees motivated?",
        "Do you remember what it was like to have dreams?"
      ],
      [
        "What’s cookin’, good lookin’?",
        "Please don’t tell HR I said that, I really didn’t mean anything by it."
      ],
      [
        "Hey, do you need friends?",
        "Should we hang out sometime?",
        "What are you doing this weekend?",
        "Do you want to come to my birthday party?"
      ],
      [
        "What’s your industry’s best kept secret?",
        "What do you know about business that no one else does?",
        "Where is the treasure? WHERE ARE YOU HIDING THE TREASURE?"
      ],
      [
        "Where do you go at night?",
        "Do you ever have nightmares?",
        "Are you ever suspicious of people?"
      ]
    ]
    |> Enum.random()
  end

  def notify_accepted_friend_request(
        %Profile{} = from_profile,
        %Profile{} = to_profile
      ) do
    body = """

    Hi #{from_profile.persona_name},

    <br/>
    <br/>

    <p>Congratulations! #{to_profile.persona_name} / #{to_profile.real_name} has accepted your Shlink request.
    Time to ask them something personal, like:</p>

    <ul>
    #{for line <- friend_request_text(), do: "<li>#{line}</li>"}
    </ul>

    <p>Time to get the conversation going!</p>

    <br/>
    <br/>
    Thanks, <br/>
    ShlinkTeam

    """

    Shlinkedin.Profiles.create_notification(%Notification{
      from_profile_id: to_profile.id,
      to_profile_id: from_profile.id,
      type: "accepted_shlink",
      action: "has accepted your Shlink request!",
      body: ""
    })

    if to_profile.unsubscribed == false do
      Shlinkedin.Email.new_email(
        from_profile.user.email,
        "#{to_profile.persona_name} has accepted your Shlink request!",
        body
      )
      |> Shlinkedin.Mailer.deliver_later()
    end
  end

  def notify_endorsement(
        %Profile{} = from_profile,
        %Profile{} = to_profile,
        %Endorsement{} = endorsement
      ) do
    if from_profile.id != to_profile.id do
      Shlinkedin.Profiles.create_notification(%Notification{
        from_profile_id: from_profile.id,
        to_profile_id: to_profile.id,
        type: "endorsement",
        action: "endorsed you for",
        body: "#{endorsement.body}"
      })
    end
  end

  def notify_ad_click(
        %Profile{} = from_profile,
        %Profile{} = to_profile,
        %Ad{} = ad
      ) do
    if from_profile.id != to_profile.id do
      Shlinkedin.Profiles.create_notification(%Notification{
        from_profile_id: from_profile.id,
        to_profile_id: to_profile.id,
        type: "ad_click",
        action: "clicked on your ad for",
        body: "#{ad.company}"
      })
    end
  end

  def notify_testimonial(
        %Profile{} = from_profile,
        %Profile{} = to_profile,
        %Testimonial{} = testimonial
      ) do
    if from_profile.id != to_profile.id do
      Shlinkedin.Profiles.create_notification(%Notification{
        from_profile_id: from_profile.id,
        to_profile_id: to_profile.id,
        type: "testimonial",
        action: "wrote you a review: ",
        body: "#{testimonial.body}"
      })
    end
  end

  def notify_like(
        %Profile{} = from_profile,
        %Profile{} = to_profile,
        %Like{} = like
      ) do
    # get notification where to_profile is same and post id is same,
    # and then update action to "and [] also did."
    if from_profile.id != to_profile.id and
         Shlinkedin.Timeline.is_first_like_on_post?(from_profile, %Post{id: like.post_id}) do
      Shlinkedin.Profiles.create_notification(%Notification{
        from_profile_id: from_profile.id,
        to_profile_id: to_profile.id,
        type: "like",
        post_id: like.post_id,
        action: "reacted \"#{like.like_type}\" to your post."
      })
    end
  end

  def notify_comment_like(
        %Profile{} = from_profile,
        %Profile{} = to_profile,
        %CommentLike{} = like
      ) do
    # get notification where to_profile is same and post id is same,
    # and then update action to "and [] also did."
    # could be optimized by one query
    comment = Timeline.get_comment!(like.comment_id)
    post = Timeline.get_post!(comment.post_id)

    if from_profile.id != to_profile.id and
         Shlinkedin.Timeline.is_first_like_on_comment?(from_profile, %Comment{id: like.comment_id}) do
      Shlinkedin.Profiles.create_notification(%Notification{
        from_profile_id: from_profile.id,
        to_profile_id: to_profile.id,
        type: "like",
        post_id: post.id,
        action: "reacted \"#{like.like_type}\" to your comment."
      })
    end
  end

  def notify_vote(
        %Profile{} = from_profile,
        %Profile{} = to_profile,
        %Vote{} = vote
      ) do
    # get notification where to_profile is same and post id is same,
    # and then update action to "and [] also did."
    if from_profile.id != to_profile.id and
         Shlinkedin.News.is_first_vote_on_article?(from_profile, %Article{id: vote.article_id}) do
      Shlinkedin.Profiles.create_notification(%Notification{
        from_profile_id: from_profile.id,
        to_profile_id: to_profile.id,
        type: "vote",
        article_id: vote.article_id,
        action: "clapped your headline!"
      })
    end
  end

  def notify_post_featured(%Profile{} = to_profile, %Post{} = post) do
    body = """

    Hi #{to_profile.persona_name},

    <br/>
    <br/>

    We are excited to inform you that your post has been awarded
     <a href="shlinked.herokuapp.com/posts/#{post.id}">post of the day!</a>!!!
     +100 ShlinkPoints.

    <br/>
    <br/>
    Thanks, <br/>
    ShlinkTeam

    """

    Shlinkedin.Profiles.create_notification(%Notification{
      from_profile_id: 3,
      to_profile_id: to_profile.id,
      type: "featured",
      post_id: post.id,
      action: "has decided to award you post of the day!"
    })

    if to_profile.unsubscribed == false do
      Shlinkedin.Email.new_email(
        to_profile.user.email,
        "You've been awarded post of the day!",
        body
      )
      |> Shlinkedin.Mailer.deliver_later()
    end
  end

  def notify_profile_badge(%Profile{} = to_profile, badge) do
    body = """

    Hi #{to_profile.persona_name},

    <br/>
    <br/>

    You have been awarded the #{badge} badge!!! It's been added to your trophy case on your profile.

    <br/>
    <br/>
    Congrats! <br/>
    ShlinkTeam

    """

    Shlinkedin.Profiles.create_notification(%Notification{
      from_profile_id: 3,
      to_profile_id: to_profile.id,
      type: "new_badge",
      action: "has awarded you the #{badge} badge! It's been added to your trophy case."
    })

    if to_profile.unsubscribed == false do
      Shlinkedin.Email.new_email(
        to_profile.user.email,
        "You got an award!",
        body
      )
      |> Shlinkedin.Mailer.deliver_later()
    end
  end

  def notify_post(
        %Profile{} = from_profile,
        %Profile{} = _to_profile,
        %Post{} = post
      ) do
    for username <- post.profile_tags do
      to_profile = Shlinkedin.Profiles.get_profile_by_username(username)

      Shlinkedin.Profiles.create_notification(%Notification{
        from_profile_id: from_profile.id,
        to_profile_id: to_profile.id,
        type: "post_tag",
        post_id: post.id,
        action: "tagged you in a post: ",
        body: "#{post.body}"
      })
    end
  end

  def notify_comment(
        %Profile{} = from_profile,
        %Profile{} = to_profile,
        %Comment{} = comment
      ) do
    for username <- comment.profile_tags do
      to_profile = Shlinkedin.Profiles.get_profile_by_username(username)

      Shlinkedin.Profiles.create_notification(%Notification{
        from_profile_id: from_profile.id,
        to_profile_id: to_profile.id,
        type: "comment",
        post_id: comment.post_id,
        action: "tagged you in a comment: ",
        body: "#{comment.body}"
      })
    end

    if from_profile.id != to_profile.id do
      Shlinkedin.Profiles.create_notification(%Notification{
        from_profile_id: from_profile.id,
        to_profile_id: to_profile.id,
        type: "comment",
        post_id: comment.post_id,
        action: "commented on your post: ",
        body: "#{comment.body}"
      })
    end
  end
end
